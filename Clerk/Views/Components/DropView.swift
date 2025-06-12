import SwiftUI
import SwiftData

struct DropView: View {
    @Environment(\.modelContext) private var modelContext
    let currentFolder: FolderItem?
    @State private var isTargeted: Bool = false
    @State private var showCannotMoveAlert = false
    @State private var cannotMoveMessage = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                    .dropDestination(for: TransferableFileItemID.self) { droppedItems, location in
                        guard let droppedItem = droppedItems.first else { return false }
                        
                        // Fetch the FileItem from the model context using its ID
                        guard let fileToMove = modelContext.model(for: droppedItem.id) as? FileItem else {
                            print("Error: Could not find FileItem with ID \(droppedItem.id)")
                            return false
                        }
                        
                        // Prevent dropping a file into its current parent folder
                        if fileToMove.parent?.persistentModelID == currentFolder?.persistentModelID {
                            cannotMoveMessage = "'\(fileToMove.name)' is already in this folder."
                            showCannotMoveAlert = true
                            return false
                        }
                        
                        // Move the file
                        let oldURL = fileToMove.fullURL
                        let originalParent = fileToMove.parent
                        fileToMove.parent = currentFolder
                        let newURL = fileToMove.fullURL
                        
                        // Ensure the destination directory exists
                        let destinationDirectory = newURL.deletingLastPathComponent()
                        do {
                            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            print("Error creating destination directory \(destinationDirectory): \(error)")
                            fileToMove.parent = originalParent
                            return false
                        }
                        
                        do {
                            try FileManager.default.moveItem(at: oldURL, to: newURL)
                            print("Successfully moved file from '\(oldURL.path)' to '\(newURL.path)'")
                            return true
                        } catch {
                            print("Error moving file from '\(oldURL.path)' to '\(newURL.path)': \(error)")
                            fileToMove.parent = originalParent
                            return false
                        }
                    } isTargeted: { targeting in
                        isTargeted = targeting
                    }
                
                if isTargeted {
                    VStack {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Drop here to move file")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(height: 300)
        .alert("Cannot Move File", isPresented: $showCannotMoveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cannotMoveMessage)
        }
    }
} 