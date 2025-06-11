import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(PlainButtonStyle())
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
            // Custom preview for the drag operation
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.blue)
                Text(file.name)
            }
            .padding(10)
            .background(.regularMaterial) // Use a material background for the preview
            .cornerRadius(8)
            .shadow(radius: 3)
        }
    }
}
