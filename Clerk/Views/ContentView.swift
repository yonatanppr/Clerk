import SwiftUI
// In ContentView.swift

struct ContentView: View {
    @State private var navigationPath = NavigationPath()
    // Add this new state variable
    @State private var showTestAlert = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FileSystemView(currentFolder: nil, navigationPath: $navigationPath)
                .navigationDestination(for: FolderItem.self) { folder in
                    FileSystemView(currentFolder: folder, navigationPath: $navigationPath)
                }
        }
        // Add these two modifiers
        .onOpenURL { url in
            if url.host == "test" {
                self.showTestAlert = true
            }
        }
        .alert("Test Successful!", isPresented: $showTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The main app was successfully opened by the simplified test extension.")
        }
    }
}

#Preview {
    // ContentView preview will also benefit from a model container if it uses SwiftData directly
    // or through its child views like FileSystemView.
    ContentView()
        .modelContainer(for: FolderItem.self, inMemory: true) // Basic in-memory container for ContentView preview
}
