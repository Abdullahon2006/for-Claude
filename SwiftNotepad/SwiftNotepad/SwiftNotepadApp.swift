import SwiftUI

@main
struct SwiftNotepadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New") { appState.newFile() }
                    .keyboardShortcut("n", modifiers: .command)

                Button("Open...") { appState.openFile() }
                    .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(appState.recentFiles, id: \.absoluteString) { url in
                        Button(url.lastPathComponent) { appState.open(url: url) }
                    }
                    if !appState.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Menu") { appState.clearRecentFiles() }
                    }
                }

                Divider()

                Button("Save") { appState.save() }
                    .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") { appState.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            // View menu — font size controls
            CommandGroup(after: .windowSize) {
                Divider()
                Button("Larger Font")       { appState.increaseFontSize() }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Smaller Font")      { appState.decreaseFontSize() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Default Font Size") { appState.resetFontSize() }
                    .keyboardShortcut("0", modifiers: .command)
            }

            CommandGroup(replacing: .help) {}
        }
    }
}
