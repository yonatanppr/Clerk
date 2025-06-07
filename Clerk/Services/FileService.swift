import Foundation
import SwiftData

struct FileService {
    static func deleteFile(_ file: FileItem, modelContext: ModelContext) {
        // Delete the physical file
        do {
            try FileManager.default.removeItem(at: file.fullURL)
            // Delete the model
            modelContext.delete(file)
            try modelContext.save()
            print("Successfully deleted file: \(file.name)")
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }
} 