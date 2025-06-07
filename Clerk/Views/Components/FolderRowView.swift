import SwiftUI


struct FolderRowView: View {
    let folder: FolderItem
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(value: folder) {
            HStack {
                Image(systemName: "folder")
                Text(folder.name)
            }
        }
        .contextMenu {
            Button("Rename") {
                onRename()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}
