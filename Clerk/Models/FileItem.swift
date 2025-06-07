import Foundation
import SwiftData

@Model
final class FileItem {
    var id: UUID
    var name: String
    var parent: FolderItem?

    init(id: UUID = UUID(), name: String, parent: FolderItem? = nil) {
        self.id = id
        self.name = name
        self.parent = parent
    }
    
    var fullURL: URL {
        let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let parent = parent {
            // Create the full path including parent folders
            var currentFolder: FolderItem? = parent
            var pathComponents: [String] = [name]
            
            while let folder = currentFolder {
                pathComponents.insert(folder.name, at: 0)
                currentFolder = folder.parent
            }
            
            return documentsFolder.appendingPathComponent(pathComponents.joined(separator: "/"))
        } else {
            return documentsFolder.appendingPathComponent(name)
        }
    }
    
    // Helper method to ensure the parent directory exists
    func ensureParentDirectoryExists() {
        let parentDirectory = fullURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
    }
}
