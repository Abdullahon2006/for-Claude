import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openFileFromFinder, object: url)
        }
    }
}

extension Notification.Name {
    static let openFileFromFinder = Notification.Name("openFileFromFinder")
}
