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
    case missingAPIKey
    case apiError(String)
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
        case .missingAPIKey:
            return "Missing API key for cloud fallback"
        case .apiError(let details):
            return "API error: \(details)"
        case .modelNotLoaded:
            return "Local LLM model could not be loaded"
        case .parsingError(let details):
            return "Failed to parse LLM output: \(details)"
        }
    }
}

// MARK: - Service
struct LLMService {
    
    // MARK: - Capability check
    private static func supportsAppleIntelligence() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    @MainActor
    private static func askUserToUseCloud() async -> Bool {
        await withUnsafeContinuation { continuation in
            guard let root = topViewController() else {
                continuation.resume(returning: false)
                return
            }
            var didResume = false
            let resumeOnce: (Bool) -> Void = { answer in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: answer)
            }

            let alert = UIAlertController(
                title: "Apple Intelligence Unavailable",
                message: "This device can’t run the on‑device model. Do you want to use cloud processing instead?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                resumeOnce(false)
            })
            alert.addAction(UIAlertAction(title: "Use Cloud", style: .default) { _ in
                resumeOnce(true)
            })
            root.present(alert, animated: true)
        }
    }

    /// Finds the top‑most view controller to present the alert from.
    private static func topViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
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
    
    // MARK: - Cloud fallback (OpenRouter)
    private static let apiKey: String? = {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let key = dict["OPENROUTER_API_KEY"] as? String
        else { return nil }
        return key
    }()

    private struct OpenRouterChatRequest: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int?

        struct Message: Codable {
            let role: String
            let content: [ContentPart]
        }

        struct ContentPart: Codable {
            let type: String
            let text: String?
            let image_url: ImageURL?

            init(text: String) {
                self.type = "text"
                self.text = text
                self.image_url = nil
            }

            init(base64Image: String) {
                self.type = "image_url"
                self.text = nil
                self.image_url = ImageURL(url: "data:image/jpeg;base64,\(base64Image)")
            }

            struct ImageURL: Codable { let url: String }
        }
    }

    private struct OpenRouterResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct OpenRouterError: Codable {
        struct Detail: Codable { let message: String }
        let error: Detail
    }

    private static func analyzeViaOpenRouter(
        images: [UIImage],
        existingFolders: [FolderItem],
        prompt: String
    ) async throws -> (
        summary: String, title: String, folderSuggestion: FolderSuggestion,
        documentType: ScannedDocument.DocumentType, requiredAction: ScannedDocument.RequiredAction?
    ) {
        guard let apiKey else { throw LLMError.missingAPIKey }

        // Convert images to base64
        let base64Images = images.compactMap { img -> String? in
            img.jpegData(compressionQuality: 0.7)?.base64EncodedString()
        }
        guard !base64Images.isEmpty else { throw LLMError.processingError }

        // Build request
        let parts: [OpenRouterChatRequest.ContentPart] =
            [OpenRouterChatRequest.ContentPart(text: prompt)] +
            base64Images.map { OpenRouterChatRequest.ContentPart(base64Image: $0) }

        let body = OpenRouterChatRequest(
            model: "google/gemma-3-27b-it:free",
            messages: [.init(role: "user", content: parts)],
            max_tokens: 1500
        )

        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(OpenRouterError.self, from: data) {
                throw LLMError.apiError(err.error.message)
            }
            throw LLMError.apiError("HTTP \( (resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        let routerResp = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard var content = routerResp.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        if content.hasPrefix("```json\n") { content.removeFirst(7) }
        if content.hasSuffix("\n```")    { content.removeLast(4) }

        guard
            let jsonData = content.data(using: .utf8),
            let parsed  = try? JSONDecoder().decode(LLMResponse.self, from: jsonData)
        else { throw LLMError.invalidResponse }

        let folderSuggestion = FolderSuggestion(
            suggestedFolder: parsed.suggestedFolder,
            shouldCreateNewFolder: parsed.shouldCreateNewFolder,
            newFolderName: parsed.newFolderName
        )
        let docType = ScannedDocument.DocumentType(rawValue: parsed.documentType) ?? .unknown

        let required: ScannedDocument.RequiredAction?
        if let act = parsed.requiredAction {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let due = act.dueDate.flatMap { df.date(from: $0) }
            required = ScannedDocument.RequiredAction(
                actionType: ScannedDocument.RequiredAction.ActionType(rawValue: act.actionType) ?? .other,
                description: act.description,
                dueDate: due,
                priority: ScannedDocument.RequiredAction.Priority(rawValue: act.priority) ?? .medium
            )
        } else {
            required = nil
        }

        return (parsed.summary, parsed.title, folderSuggestion, docType, required)
    }
    
    private static func buildPrompt(ocrText: String, folderStructure: String) -> String {
        """
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
        // Decide which path to take
        if !supportsAppleIntelligence() {
            let useCloud = await askUserToUseCloud()
            if useCloud {
                // Re‑use the prompt we build later; build early here
                let folderStructure = existingFolders
                    .map { $0.getPath().map(\.name).joined(separator: "/") }
                    .joined(separator: "\n")
                let prompt = Self.buildPrompt(ocrText: try await recognizeText(in: images),
                                              folderStructure: folderStructure)
                return try await analyzeViaOpenRouter(images: images,
                                                      existingFolders: existingFolders,
                                                      prompt: prompt)
            } else {
                throw LLMError.modelNotLoaded
            }
        }
        
        // 1. OCR
        let ocrText = try await recognizeText(in: images)
        guard !ocrText.isEmpty else { throw LLMError.processingError }
        
        // 2. Build prompt
        let folderStructure = existingFolders
            .map { $0.getPath().map(\.name).joined(separator: "/") }
            .joined(separator: "\n")
        let prompt = Self.buildPrompt(ocrText: ocrText, folderStructure: folderStructure)
        
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
