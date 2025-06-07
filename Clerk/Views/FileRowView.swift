import SwiftUI

struct FileRowView: View {
    let file: FileItem
    let onTap: () -> Void
    
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
                // TODO: Implement file deletion
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
