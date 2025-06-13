import SwiftUI
import SwiftData

@main
struct ClerkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // This catches the URL from the extension
                    handleIncomingURL(url)
                }
        }
        .modelContainer(for: FolderItem.self)
    }

    private func handleIncomingURL(_ url: URL) {
        // This function parses the URL and posts a notification
        guard url.scheme == "clerk",
              url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fileNameItem = components.queryItems?.first(where: { $0.name == "filename" }),
              let fileName = fileNameItem.value else {
            return
        }

        // Use your correct App Group ID here
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.clerkapp.Clerk") else {
            return
        }

        let fileURL = containerURL.appendingPathComponent(fileName)
        
        // Post a notification containing the file URL for the view to handle
        NotificationCenter.default.post(name: .didReceiveFile, object: fileURL)
    }
}

// Defines the custom notification name
extension Notification.Name {
    static let didReceiveFile = Notification.Name("didReceiveFile")
}
