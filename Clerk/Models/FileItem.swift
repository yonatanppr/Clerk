import Foundation
import SwiftData

@Model
final class FileItem {
    var id: UUID
    var name: String
    var url: URL
    var parent: FolderItem?

    init(id: UUID = UUID(), name: String, url: URL, parent: FolderItem? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.parent = parent
    }
}
