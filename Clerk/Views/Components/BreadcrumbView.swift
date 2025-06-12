import SwiftUI
import SwiftData

struct BreadcrumbView: View {
    let path: [FolderItem]
    // Called when a folder in the breadcrumb path (excluding the last item) is tapped.
    let onNavigate: (FolderItem) -> Void
    // Called when the dedicated "Root" or "Home" button is tapped.
    let onNavigateToRoot: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHomeTargeted: Bool = false
    @State private var targetedFolderIndex: Int? = nil
    @State private var showCannotMoveAlert = false
    @State private var cannotMoveMessage = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Dedicated "Home" button
                Button(action: onNavigateToRoot) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4) // Give it some space
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                .background(isHomeTargeted ? Color.gray.opacity(0.1) : Color.clear)
                .cornerRadius(5)
                .dropDestination(for: TransferableFileItemID.self) { droppedItems, location in
                    handleFileDrop(droppedItems: droppedItems, targetFolder: nil)
                } isTargeted: { targeting in
                    isHomeTargeted = targeting
                }

                ForEach(path.indices, id: \.self) { index in
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)

                    let folder = path[index]

                    // Don't make the last item in the path a button,
                    // as it represents the current folder.
                    if index == path.count - 1 {
                        Text(folder.name)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .foregroundColor(.primary)
                            .underline()
                            .cornerRadius(5)
                    } else {
                        Button(action: {
                            onNavigate(folder)
                        }) {
                            Text(folder.name)
                                .padding(.horizontal, 4)
                                .foregroundColor(.blue)
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(PlainButtonStyle())
                        .background(targetedFolderIndex == index ? Color.gray.opacity(0.1) : Color.clear)
                        .cornerRadius(5)
                        .dropDestination(for: TransferableFileItemID.self) { droppedItems, location in
                            handleFileDrop(droppedItems: droppedItems, targetFolder: folder)
                        } isTargeted: { targeting in
                            targetedFolderIndex = targeting ? index : nil
                        }
                    }
                }
            }
            .padding(.vertical, 4) // Padding inside the scrollable content
            .padding(.horizontal) // Padding for the ends of the scrollable content
        }
        .frame(height: 30) // Give the breadcrumb bar a fixed height
        .background(Color(.systemGray6).opacity(0.7)) // Optional: background color
        .cornerRadius(8) // Optional: rounded corners
        // Outer padding will be handled by the parent view (FileSystemView)
        .alert("Cannot Move File", isPresented: $showCannotMoveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cannotMoveMessage)
        }
    }
    
    private func handleFileDrop(droppedItems: [TransferableFileItemID], targetFolder: FolderItem?) -> Bool {
        guard let droppedItem = droppedItems.first else { return false }
        
        // Fetch the FileItem from the model context using its ID
        guard let fileToMove = modelContext.model(for: droppedItem.id) as? FileItem else {
            print("Error: Could not find FileItem with ID \(droppedItem.id)")
            return false
        }
      
        // Move the file to the target folder
        let oldURL = fileToMove.fullURL
        let originalParent = fileToMove.parent
        fileToMove.parent = targetFolder
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
    }
}
