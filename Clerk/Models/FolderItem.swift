import SwiftData
import Foundation

@Model
final class FolderItem {
    var name: String
    var creationDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \FileItem.parent)
    var files: [FileItem] = []

    // Relationship to parent folder
    var parent: FolderItem?

    // Relationship to subfolders. If a folder is deleted, its subfolders are also deleted (cascade).
    @Relationship(deleteRule: .cascade, inverse: \FolderItem.parent)
    var subfolders: [FolderItem] = []

    init(name: String, creationDate: Date = Date(), parent: FolderItem? = nil) {
        self.name = name
        self.creationDate = creationDate
        self.parent = parent
    }

    // Helper function to get the path from root to this folder
    func getPath() -> [FolderItem] {
        var path: [FolderItem] = []
        var currentItem: FolderItem? = self
        while let item = currentItem {
            path.insert(item, at: 0) // Prepend to get the correct order: [Root, ..., Self]
            currentItem = item.parent
        }
        return path
    }
}
