import Foundation
import CoreML
import UIKit

enum LocalLLMError: Error, LocalizedError {
    case modelNotFound
    case invalidResponse
    case processingError(Error)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Local LLM model not found"
        case .invalidResponse:
            return "Invalid response from local LLM"
        case .processingError(let error):
            return "Processing error: \(error.localizedDescription)"
        }
    }
}

struct LocalLLMService {
    private static var model: MLModel = {
        guard let url = Bundle.main.url(forResource: "LocalLLM", withExtension: "mlmodelc") else {
            fatalError("LocalLLM.mlmodelc missing from bundle")
        }
        return try! MLModel(contentsOf: url)
    }()

    static func analyzeDocument(images: [UIImage], existingFolders: [FolderItem]) async throws -> (summary: String, title: String, folderSuggestion: FolderSuggestion, documentType: ScannedDocument.DocumentType, requiredAction: ScannedDocument.RequiredAction?) {
        // Convert folder structure to text
        let folderStructure = existingFolders.map { folder -> String in
            folder.getPath().map { $0.name }.joined(separator: "/")
        }.joined(separator: "\n")

        let prompt = """
        Analyze these document images and provide:
        1. A concise summary of the content
        2. A suitable title for the document
        3. A suggestion for where to store this document based on the existing folder structure
        4. The type of document (spam, informational, or action_required)
        5. If action is required, provide details about the action

        Current folder structure:
        \(folderStructure)

        Format your response as JSON with keys summary, title, suggestedFolder, shouldCreateNewFolder, newFolderName, documentType and requiredAction.
        """

        do {
            let provider = try MLDictionaryFeatureProvider(dictionary: ["prompt": prompt])
            let output = try model.prediction(from: provider)
            guard let response = output.featureValue(for: "text")?.stringValue else {
                throw LocalLLMError.invalidResponse
            }

            // Parse JSON
            guard let data = response.data(using: .utf8),
                  let llmResponse = try? JSONDecoder().decode(LLMResponse.self, from: data) else {
                throw LocalLLMError.invalidResponse
            }

            let folderSuggestion = FolderSuggestion(
                suggestedFolder: llmResponse.suggestedFolder,
                shouldCreateNewFolder: llmResponse.shouldCreateNewFolder,
                newFolderName: llmResponse.newFolderName
            )

            let documentType = ScannedDocument.DocumentType(rawValue: llmResponse.documentType) ?? .unknown
            let requiredAction: ScannedDocument.RequiredAction?
            if let action = llmResponse.requiredAction {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dueDate = action.dueDate.flatMap { dateFormatter.date(from: $0) }
                requiredAction = ScannedDocument.RequiredAction(
                    actionType: ScannedDocument.RequiredAction.ActionType(rawValue: action.actionType) ?? .other,
                    description: action.description,
                    dueDate: dueDate,
                    priority: ScannedDocument.RequiredAction.Priority(rawValue: action.priority) ?? .medium
                )
            } else {
                requiredAction = nil
            }

            return (llmResponse.summary, llmResponse.title, folderSuggestion, documentType, requiredAction)
        } catch {
            throw LocalLLMError.processingError(error)
        }
    }
}

// Response model reused from LLMService
private struct LLMResponse: Codable {
    let summary: String
    let title: String
    let suggestedFolder: String?
    let shouldCreateNewFolder: Bool
    let newFolderName: String?
    let documentType: String
    let requiredAction: ActionResponse?

    struct ActionResponse: Codable {
        let actionType: String
        let description: String
        let dueDate: String?
        let priority: String
    }
}
