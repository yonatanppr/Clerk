import SwiftUI
import SwiftData
import UniformTypeIdentifiers // For UTType

struct FolderRowView: View {
    let folder: FolderItem
    let onRename: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted: Bool = false // For visual feedback on drag hover
    @State private var showCannotMoveAlert = false
    @State private var cannotMoveMessage = ""

    var body: some View {
        NavigationLink(value: folder) {
            HStack {
                Image(systemName: "folder")
                Text(folder.name)
            }
        }
        .padding(.vertical, 4) // Add some padding to make it a better drop target
        .cornerRadius(5)
        .contentShape(Rectangle()) // Ensures the entire area can be a drop target
        .contextMenu {
            Button("Rename") {
                onRename()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .dropDestination(for: TransferableFileItemID.self) { droppedItems, location in
            guard let droppedItem = droppedItems.first else { return false }

            // Fetch the FileItem from the model context using its ID
            guard let fileToMove = modelContext.model(for: droppedItem.id) as? FileItem else {
                print("Error: Could not find FileItem with ID \(droppedItem.id)")
                return false
            }

            // Prevent dropping a file into its current parent folder
            if fileToMove.parent?.persistentModelID == folder.persistentModelID {
                cannotMoveMessage = "'\(fileToMove.name)' is already in the folder '\(folder.name)'."
                showCannotMoveAlert = true
                print(cannotMoveMessage)
                return false // Indicate the operation was handled, but no change made
            }

            // --- Physical File Move (Crucial Step) ---
            let oldURL = fileToMove.fullURL
            let originalParent = fileToMove.parent // Store original parent for rollback
            fileToMove.parent = folder
            let newURL = fileToMove.fullURL

            // Ensure the destination directory exists
            let destinationDirectory = newURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating destination directory \(destinationDirectory): \(error)")
                // Revert parent change if directory creation fails and we can't move
                fileToMove.parent = originalParent
                // Consider showing an alert to the user
                return false
            }

            do {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                print("Successfully moved file from '\(oldURL.path)' to '\(newURL.path)'")
                // The parent is already set correctly from above for newURL calculation.
            } catch {
                print("Error moving file from '\(oldURL.path)' to '\(newURL.path)': \(error)")
                // If move fails, revert the parent change in SwiftData to keep model consistent with file system
                fileToMove.parent = originalParent
                // Consider showing an alert to the user
                return false // Indicate failure
            }

            // SwiftData should automatically save changes.
            // If you encounter issues, you might need an explicit try? modelContext.save()
            return true // Indicate success
        } isTargeted: { targeting in
            isTargeted = targeting
        }
        .alert("Cannot Move File", isPresented: $showCannotMoveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cannotMoveMessage)
        }
    }
}
