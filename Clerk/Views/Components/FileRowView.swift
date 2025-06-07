import SwiftUI
import SwiftData

struct FileRowView: View {
    let file: FileItem
    let onTap: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            HStack {
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
    }
}
