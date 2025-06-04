import SwiftUI
import SwiftData

@main
struct ClerkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FolderItem.self)
    }
}
