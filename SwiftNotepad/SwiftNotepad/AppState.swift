import AppKit
import Combine

class AppState: ObservableObject {
    @Published var content: String = ""
    @Published var currentFileURL: URL?
    @Published var isModified: Bool = false

    // Font size — persisted
    @Published var fontSize: CGFloat = 14

    // Status bar
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var wordCount: Int = 0
    @Published var charCount: Int = 0

    // Recent files
    @Published var recentFiles: [URL] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Restore persisted font size
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        if stored > 0 { fontSize = CGFloat(stored) }

        createDefaultNotesFolder()
        loadRecentFiles()

        // Auto-save 3 seconds after the last edit
        $content
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isModified, self.currentFileURL != nil else { return }
                self.save()
            }
            .store(in: &cancellables)

        // Persist font size changes
        $fontSize
            .dropFirst()
            .sink { UserDefaults.standard.set(Double($0), forKey: "fontSize") }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFinderOpen(_:)),
            name: .openFileFromFinder, object: nil
        )
    }

    // MARK: - Font size

    func increaseFontSize() { fontSize = min(fontSize + 1, 36) }
    func decreaseFontSize() { fontSize = max(fontSize - 1,  9) }
    func resetFontSize()    { fontSize = 14 }

    // MARK: - Cursor / status bar

    func updateCursorPosition(text: String, location: Int) {
        let nsText = text as NSString
        let loc    = min(location, nsText.length)
        var line   = 1
        var lineStart = 0
        for i in 0 ..< loc {
            if nsText.character(at: i) == 0x0A {
                line += 1
                lineStart = i + 1
            }
        }
        cursorLine   = line
        cursorColumn = loc - lineStart + 1
    }

    func updateStats(text: String) {
        charCount = text.count
        wordCount = text.isEmpty ? 0 :
            text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    // MARK: - Window notifications

    @objc private func windowWillClose(_ notification: Notification) {
        guard isModified, currentFileURL != nil else { return }
        save()
    }

    @objc private func handleFinderOpen(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        open(url: url)
    }

    // MARK: - File operations

    func newFile() {
        if isModified { saveIfNeeded() }
        content = ""
        currentFileURL = nil
        isModified = false
        wordCount = 0
        charCount = 0
        updateWindowTitle()
    }

    func openFile() {
        if isModified { saveIfNeeded() }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = currentFileURL?.deletingLastPathComponent() ?? defaultNotesDirectory()
        if panel.runModal() == .OK, let url = panel.url {
            open(url: url)
        }
    }

    func open(url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            content = text
            currentFileURL = url
            isModified = false
            updateWindowTitle()
            updateStats(text: text)
            addToRecentFiles(url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            showError("Could not open file", detail: error.localizedDescription)
        }
    }

    func save() {
        guard let url = currentFileURL else { saveAs(); return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            isModified = false
            updateWindowTitle()
        } catch {
            showError("Could not save file", detail: error.localizedDescription)
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.directoryURL = defaultNotesDirectory()
        panel.nameFieldStringValue = "Untitled.txt"
        if panel.runModal() == .OK, let url = panel.url {
            currentFileURL = url
            save()
        }
    }

    func markModified() {
        isModified = true
        updateWindowTitle()
    }

    // MARK: - Recent files

    func addToRecentFiles(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 10 { recentFiles = Array(recentFiles.prefix(10)) }
        saveRecentFiles()
    }

    func clearRecentFiles() {
        recentFiles = []
        UserDefaults.standard.removeObject(forKey: "recentFiles")
    }

    private func loadRecentFiles() {
        let strings = UserDefaults.standard.stringArray(forKey: "recentFiles") ?? []
        recentFiles = strings.compactMap { URL(string: $0) }
    }

    private func saveRecentFiles() {
        UserDefaults.standard.set(recentFiles.map(\.absoluteString), forKey: "recentFiles")
    }

    // MARK: - Helpers

    private func saveIfNeeded() {
        guard currentFileURL != nil else { return }
        save()
    }

    private func defaultNotesDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Notes")
    }

    private func createDefaultNotesFolder() {
        let dir = defaultNotesDirectory()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func updateWindowTitle() {
        DispatchQueue.main.async {
            let base = self.currentFileURL?.lastPathComponent ?? "Untitled"
            NSApp.windows.first?.title = self.isModified ? "\(base) \u{2022}" : base
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText    = message
        alert.informativeText = detail
        alert.alertStyle     = .warning
        alert.runModal()
    }
}
