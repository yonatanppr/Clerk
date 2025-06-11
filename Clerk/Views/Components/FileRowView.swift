import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dragState: DragState
    @State private var showingDeleteConfirmation = false
    @State private var showCannotMoveAlert = false
    @State private var cannotMoveMessage = ""
    
    var body: some View {
        HStack {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
            Image(systemName: "doc.richtext")
                .foregroundColor(.blue)
            Text(file.name)
                .foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete File", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                FileService.deleteFile(file, modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(file.name)'?")
        }
        .draggable(TransferableFileItemID(id: file.persistentModelID)) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.blue)
                Text(file.name)
            }
            .padding(10)
            .background(.regularMaterial)
            .cornerRadius(8)
            .shadow(radius: 3)
        }
        .dropDestination(for: TransferableFileItemID.self) { droppedItems, location in
            guard let droppedItem = droppedItems.first else { return false }
            
            // Fetch the FileItem from the model context using its ID
            guard let fileToMove = modelContext.model(for: droppedItem.id) as? FileItem else {
                print("Error: Could not find FileItem with ID \(droppedItem.id)")
                return false
            }
            
            // Prevent dropping a file into its current parent folder
            if fileToMove.parent?.persistentModelID == file.parent?.persistentModelID {
                cannotMoveMessage = "'\(fileToMove.name)' is already in the same folder."
                showCannotMoveAlert = true
                return false
            }
            
            // Move the file to the same parent as the target file
            let oldURL = fileToMove.fullURL
            let originalParent = fileToMove.parent
            fileToMove.parent = file.parent
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
            } catch {
                print("Error moving file from '\(oldURL.path)' to '\(newURL.path)': \(error)")
                fileToMove.parent = originalParent
                return false
            }
            
            return true
        } isTargeted: { targeting in
            dragState.isDraggingOver = targeting
        }
        .alert("Cannot Move File", isPresented: $showCannotMoveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cannotMoveMessage)
        }
    }
}
