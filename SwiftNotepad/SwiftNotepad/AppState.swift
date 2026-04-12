import AppKit
import Combine

class AppState: ObservableObject {
    @Published var content: String = ""
    @Published var currentFileURL: URL?
    @Published var isModified: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        createDefaultNotesFolder()

        // Auto-save 3 seconds after the last edit
        $content
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isModified, self.currentFileURL != nil else { return }
                self.save()
            }
            .store(in: &cancellables)

        // Save on window close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard isModified else { return }
        if currentFileURL != nil {
            save()
        }
    }

    // MARK: - File operations

    func newFile() {
        if isModified { saveIfNeeded() }
        content = ""
        currentFileURL = nil
        isModified = false
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
            content = try String(contentsOf: url, encoding: .utf8)
            currentFileURL = url
            isModified = false
            updateWindowTitle()
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
        panel.nameFieldStringValue = "Untitled.md"
        if panel.runModal() == .OK, let url = panel.url {
            currentFileURL = url
            save()
        }
    }

    func markModified() {
        isModified = true
        updateWindowTitle()
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
            let base: String
            if let url = self.currentFileURL {
                base = url.lastPathComponent
            } else {
                base = "Untitled"
            }
            NSApp.windows.first?.title = self.isModified ? "\(base) \u{2022}" : base
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.runModal()
    }
}
