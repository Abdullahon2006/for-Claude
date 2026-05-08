import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NotepadTextView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
            .onAppear { appState.updateWindowTitle() }
            .onOpenURL { url in appState.open(url: url) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard
                let data = item as? Data,
                let urlString = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let url = URL(string: urlString)
            else { return }
            DispatchQueue.main.async { appState.open(url: url) }
        }
        return true
    }
}
