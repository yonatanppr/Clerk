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
}
