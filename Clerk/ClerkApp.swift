import SwiftUI
import SwiftData

@main
struct ClerkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // This will handle URLs from the Share Extension
                    // For now, it just prints the URL
                    print("Received URL: \(url)")
                }
        }
        .modelContainer(for: FolderItem.self)
    }
}
