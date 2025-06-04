import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            FileSystemView(currentFolder: nil) // Start at the root (nil currentFolder)
        }
    }
}

#Preview {
    // ContentView preview will also benefit from a model container if it uses SwiftData directly
    // or through its child views like FileSystemView.
    ContentView()
        .modelContainer(for: FolderItem.self, inMemory: true) // Basic in-memory container for ContentView preview
}
