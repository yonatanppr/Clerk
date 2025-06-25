import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Errors
enum LLMError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)      // kept for compatibility with calling sites
    case processingError
    case modelNotLoaded
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from local LLM"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .processingError:
            return "Error processing document"
        case .modelNotLoaded:
            return "Local LLM model could not be loaded"
        case .parsingError(let details):
            return "Failed to parse LLM output: \(details)"
        }
    }
}

// MARK: - Service
struct LLMService {
    
    // MARK: Private helpers

    // MARK: - Local LLM helpers
    #if canImport(FoundationModels)
    @available(iOS 18.0, *)
    private static let languageModel: SystemLanguageModel = .default

    @available(iOS 18.0, *)
    private static func generateCompletion(for prompt: String, maxTokens: Int) throws -> String {
        // Ensure the model is actually available on this device / region.
        guard languageModel.availability == .available else {
            throw LLMError.modelNotLoaded
        }
        var config = LanguageModelSession.Configuration()
        config.maxTokens = maxTokens

        let session = try languageModel.makeSession(configuration: config)
        let response = try session.respond(to: prompt, generating: String.self)
        return response.content
    }
    #else
    /// Fallback that simply throws on older SDKs where FoundationModels isn't available.
    private static func generateCompletion(for prompt: String, maxTokens: Int) throws -> String {
        throw LLMError.modelNotLoaded
    }
    #endif
    
    /// Vision OCR
    private static func recognizeText(in images: [UIImage]) async throws -> String {
        var accumulated = ""
        for image in images {
            guard let cg = image.cgImage else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cg)
            try handler.perform([request])
            let text = request.results?
                .compactMap { ($0 as? VNRecognizedTextObservation)?
                    .topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            accumulated += text + "\n"
        }
        return accumulated
    }
    
    // MARK: Public API
    static func analyzeDocument(
        images: [UIImage],
        existingFolders: [FolderItem]
    ) async throws -> (
        summary: String,
        title: String,
        folderSuggestion: FolderSuggestion,
        documentType: ScannedDocument.DocumentType,
        requiredAction: ScannedDocument.RequiredAction?
    ) {
        
        // 1. OCR
        let ocrText = try await recognizeText(in: images)
        guard !ocrText.isEmpty else { throw LLMError.processingError }
        
        // 2. Build prompt
        let folderStructure = existingFolders
            .map { $0.getPath().map(\.name).joined(separator: "/") }
            .joined(separator: "\n")
        
        let prompt = """
        You are a document‑understanding assistant running entirely on‑device.

        The scanned document’s OCR text is between ``` fences.
        The current folder hierarchy is between ~~~. If you find a suitable existing folder, suggest it. 
        If no existing folder is appropriate, suggest creating a new one with a descriptive name.

        Generate a JSON object with:
          • summary
          • title
          • suggestedFolder
          • shouldCreateNewFolder
          • newFolderName
          • documentType  (spam | informational | action_required)
          • requiredAction (object or null)
        
        For action detection:
        - If the document is spam or an advertisement with no required action, set documentType to "spam"
        - If the document contains important information but no required action, set documentType to "informational"
        - If the document requires any action (payment, form submission, appointment, etc.), set documentType to "action_required" and provide action details
                
        
        Format your response as JSON with these fields:
        {
            "summary": "your short summary here",
            "title": "your title here",
            "suggestedFolder": "path/to/existing/folder or null if no suitable folder",
            "shouldCreateNewFolder": true/false,
            "newFolderName": "suggested new folder name or null if not creating new folder",
            "documentType": "spam/informational/action_required",
            "requiredAction": {
                        "actionType": "payment/form/appointment/other",
                        "description": "short description of the required action",
                        "dueDate": "YYYY-MM-DD or null if no due date",
                        "priority": "high/medium/low"
            } or null if no action required
        }

        ```
        \(ocrText)
        ```
        ~~~
        \(folderStructure)
        ~~~
        """
        
        // 3. Local inference
        let raw: String
        print("OS:", ProcessInfo.processInfo.operatingSystemVersion)
        if #available(iOS 18.0, *) {
            raw = try generateCompletion(for: prompt, maxTokens: 768)
        } else {
            throw LLMError.modelNotLoaded
        }
        
        // 4. Clean & parse
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }
        
        let llmResponse: LLMResponse
        do {
            llmResponse = try JSONDecoder().decode(LLMResponse.self, from: jsonData)
        } catch {
            throw LLMError.parsingError(cleaned)
        }
        
        // 5. Convert to app types
        let folderSuggestion = FolderSuggestion(
            suggestedFolder: llmResponse.suggestedFolder,
            shouldCreateNewFolder: llmResponse.shouldCreateNewFolder,
            newFolderName: llmResponse.newFolderName
        )
        
        let documentType = ScannedDocument.DocumentType(rawValue: llmResponse.documentType) ?? .unknown
        
        let requiredAction: ScannedDocument.RequiredAction?
        if let action = llmResponse.requiredAction {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dueDate = action.dueDate.flatMap { df.date(from: $0) }
            
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
    }
}

// MARK: - Response models
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

struct FolderSuggestion {
    let suggestedFolder: String?
    let shouldCreateNewFolder: Bool
    let newFolderName: String?
}
