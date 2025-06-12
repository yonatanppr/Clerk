import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

// 1. Define a custom UTType for our draggable FileItem.
// This helps identify the type of data being dragged.
extension UTType {
    static var fileItemDrag = UTType(exportedAs: "clerkapp.Clerk.fileitemdrag")
}

// 2. Create a struct to wrap the FileItem's PersistentIdentifier.
// This struct will conform to Transferable, allowing it to be used in drag-and-drop operations.
struct TransferableFileItemID: Codable, Transferable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .fileItemDrag)
    }
}