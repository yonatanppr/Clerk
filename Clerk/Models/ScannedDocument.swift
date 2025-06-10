import Foundation
import SwiftUI

class ScannedDocument: ObservableObject {
    let id: UUID
    let images: [UIImage]
    @Published var llmSummary: String
    @Published var suggestedTitle: String
    @Published var suggestedFolder: String?
    @Published var shouldCreateNewFolder: Bool
    @Published var newFolderName: String?
    @Published var processingStatus: ProcessingStatus
    
    init(images: [UIImage]) {
        self.id = UUID()
        self.images = images
        self.llmSummary = ""
        self.suggestedTitle = ""
        self.suggestedFolder = nil
        self.shouldCreateNewFolder = false
        self.newFolderName = nil
        self.processingStatus = .processing
    }
    
    enum ProcessingStatus {
        case processing
        case completed
        case failed(Error)
    }
} 