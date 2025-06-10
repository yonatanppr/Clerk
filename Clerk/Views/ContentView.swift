import SwiftUI

struct ContentView: View {
    // 1. Add a @State variable for the NavigationPath
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) { // 2. Use the path in NavigationStack
            FileSystemView(currentFolder: nil, navigationPath: $navigationPath) // 3. Pass the binding
        }
    }
}

#Preview {
    // ContentView preview will also benefit from a model container if it uses SwiftData directly
    // or through its child views like FileSystemView.
    ContentView()
        .modelContainer(for: FolderItem.self, inMemory: true) // Basic in-memory container for ContentView preview
}
