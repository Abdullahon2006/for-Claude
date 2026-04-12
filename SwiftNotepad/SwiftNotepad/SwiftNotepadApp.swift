import SwiftUI

@main
struct SwiftNotepadApp: App {
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
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    appState.newFile()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    appState.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    appState.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    appState.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {}
        }
    }
}
