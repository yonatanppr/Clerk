import SwiftUI
import SwiftData
import os.log

@main
struct ClerkApp: App {
    private let logger = Logger(subsystem: "com.clerkapp.Clerk", category: "App")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    logger.info("Main app received URL: \(url.absoluteString)")
                    handleIncomingURL(url)
                }
        }
        .modelContainer(for: FolderItem.self)
    }

    private func handleIncomingURL(_ url: URL) {
        logger.info("Handling incoming URL: \(url.absoluteString)")
        
        // This function parses the URL and posts a notification
        guard url.scheme == "clerk" else {
            logger.error("Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        guard url.host == "import" else {
            logger.error("Invalid URL host: \(url.host ?? "nil")")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Failed to create URL components")
            return
        }
        
        guard let fileNameItem = components.queryItems?.first(where: { $0.name == "filename" }),
              let fileName = fileNameItem.value else {
            logger.error("Failed to get filename from URL")
            return
        }

        logger.info("Processing file: \(fileName)")
        
        // Use your correct App Group ID here
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.clerkapp.Clerk") else {
            logger.error("Failed to get container URL")
            return
        }

        let fileURL = containerURL.appendingPathComponent(fileName)
        
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.error("File does not exist at path: \(fileURL.path)")
            return
        }
        
        logger.info("Posting notification for file: \(fileURL.path)")
        // Post a notification containing the file URL for the view to handle
        NotificationCenter.default.post(name: .didReceiveFile, object: fileURL)
    }
}

// Defines the custom notification name
extension Notification.Name {
    static let didReceiveFile = Notification.Name("didReceiveFile")
}
