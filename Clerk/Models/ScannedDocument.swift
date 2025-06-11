import Foundation
import SwiftUI
import EventKit

class ScannedDocument: ObservableObject {
    let id: UUID
    let images: [UIImage]
    @Published var llmSummary: String
    @Published var suggestedTitle: String
    @Published var suggestedFolder: String?
    @Published var shouldCreateNewFolder: Bool
    @Published var newFolderName: String?
    @Published var processingStatus: ProcessingStatus
    
    // Action-related properties
    @Published var documentType: DocumentType
    @Published var requiredAction: RequiredAction?
    
    init(images: [UIImage]) {
        self.id = UUID()
        self.images = images
        self.llmSummary = ""
        self.suggestedTitle = ""
        self.suggestedFolder = nil
        self.shouldCreateNewFolder = false
        self.newFolderName = nil
        self.processingStatus = .processing
        self.documentType = .unknown
        self.requiredAction = nil
    }
    
    enum ProcessingStatus {
        case processing
        case completed
        case failed(Error)
    }
    
    enum DocumentType: String, Codable {
        case spam = "spam"
        case informational = "informational"
        case actionRequired = "action_required"
        case unknown = "unknown"
    }
    
    struct RequiredAction: Codable {
        let actionType: ActionType
        let description: String
        let dueDate: Date?
        let priority: Priority
        
        enum ActionType: String, Codable {
            case payment = "payment"
            case form = "form"
            case appointment = "appointment"
            case other = "other"
        }
        
        enum Priority: String, Codable {
            case high = "high"
            case medium = "medium"
            case low = "low"
        }
    }
} 