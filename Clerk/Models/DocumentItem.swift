import SwiftUI
import SwiftData

@Model
final class DocumentItem {
    var name: String
    var creationDate: Date
    var imageData: Data
    var parent: FolderItem?
    
    init(name: String, imageData: Data, creationDate: Date = Date(), parent: FolderItem? = nil) {
        self.name = name
        self.imageData = imageData
        self.creationDate = creationDate
        self.parent = parent
    }
} 