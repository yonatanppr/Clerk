import Foundation
import UIKit

enum LLMError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case processingError
    case missingAPIKey
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from LLM service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .processingError:
            return "Error processing document"
        case .missingAPIKey:
            return "API key is missing"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

struct LLMService {
    private static let apiKey: String = {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let key = dict["OPENROUTER_API_KEY"] as? String
        else {
            fatalError("API key not found in Secrets.plist")
        }
        return key
    }()
    
    // MARK: - Request Models (Codable)
    private struct OpenRouterChatRequest: Codable {
        let model: String
        let messages: [RequestMessage]
        let max_tokens: Int?
        // let temperature: Double? // Optional
        // let stream: Bool?      // Optional

        struct RequestMessage: Codable {
            let role: String
            let content: [ContentPart] // Array to hold text and image parts
        }

        // This structure matches the [String: Any] you were building.
        // Ensure this is what 'google/gemma-3-27b-it:free' expects via OpenRouter.
        struct ContentPart: Codable {
            let type: String
            let text: String?
            let image_url: ImageUrlDetail? // Matches your existing "image_url" key within an "image" type part

            // Initializer for text part
            init(type: String = "text", text: String) {
                self.type = type
                self.text = text
                self.image_url = nil
            }
            // Initializer for image part
            // The 'type' here should be "image_url" as per the provided documentation
            init(type: String = "image_url", imageUrl: ImageUrlDetail) {
                self.type = type
                self.text = nil
                self.image_url = imageUrl
            }

        }
        struct ImageUrlDetail: Codable {
            let url: String
        }
    }
    
    static func analyzeDocument(images: [UIImage], existingFolders: [FolderItem]) async throws -> (summary: String, title: String, folderSuggestion: FolderSuggestion) {
        let apiURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        // Convert images to base64 strings
        let imageData = images.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
            return data.base64EncodedString()
        }
        
        guard !imageData.isEmpty else {
            throw LLMError.processingError
        }
        
        // Create a string representation of the folder structure
        let folderStructure = existingFolders.map { folder -> String in
            let path = folder.getPath().map { $0.name }.joined(separator: "/")
            return path
        }.joined(separator: "\n")
        
        // Prepare the prompt for the LLM
        let prompt = """
        Analyze these document images and provide:
        1. A concise summary of the content
        2. A suitable title for the document
        3. A suggestion for where to store this document based on the existing folder structure
        
        Current folder structure:
        \(folderStructure)
        
        If you find a suitable existing folder, suggest it. If no existing folder is appropriate, suggest creating a new one with a descriptive name.
        
        Format your response as JSON with these fields:
        {
            "summary": "your summary here",
            "title": "your title here",
            "suggestedFolder": "path/to/existing/folder or null if no suitable folder",
            "shouldCreateNewFolder": true/false,
            "newFolderName": "suggested new folder name or null if not creating new folder"
        }
        """
        
        // --- Prepare request body using Codable structs ---
        var contentParts: [OpenRouterChatRequest.ContentPart] = []
        contentParts.append(OpenRouterChatRequest.ContentPart(text: prompt)) // Text part
        
        for base64ImageString in imageData {
            let imageUrlDetail = OpenRouterChatRequest.ImageUrlDetail(url: "data:image/jpeg;base64,\(base64ImageString)")
            contentParts.append(OpenRouterChatRequest.ContentPart(type: "image_url", imageUrl: imageUrlDetail))
        }
        
        let requestMessages = [OpenRouterChatRequest.RequestMessage(role: "user", content: contentParts)]
        
        let modelIdentifier = "google/gemma-3-27b-it:free"

        let openRouterRequestBody = OpenRouterChatRequest(
            model: modelIdentifier,
            messages: requestMessages,
            max_tokens: 1500 // Increased token limit for more detailed response
        )
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Clerk/1.0", forHTTPHeaderField: "HTTP-Referer")
        
        do {
            request.httpBody = try JSONEncoder().encode(openRouterRequestBody)
        } catch {
            print("Error serializing request body: \(error)")
            throw LLMError.processingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                if let errorResponse = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) {
                    throw LLMError.apiError(errorResponse.error.message)
                }
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let openRouterResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            
            guard var content = openRouterResponse.choices.first?.message.content else {
                print("LLM response content is nil or empty.")
                throw LLMError.invalidResponse
            }
            
            // Strip markdown code block delimiters if present
            if content.hasPrefix("```json\n") {
                content = String(content.dropFirst("```json\n".count))
            }
            if content.hasSuffix("\n```") {
                content = String(content.dropLast("\n```".count))
            }
            
            guard let jsonData = content.data(using: .utf8),
                  let llmResponse = try? JSONDecoder().decode(LLMResponse.self, from: jsonData) else {
                print("Failed to parse LLM response content: \(openRouterResponse.choices.first?.message.content ?? "nil")")
                throw LLMError.invalidResponse
            }
            
            let folderSuggestion = FolderSuggestion(
                suggestedFolder: llmResponse.suggestedFolder,
                shouldCreateNewFolder: llmResponse.shouldCreateNewFolder,
                newFolderName: llmResponse.newFolderName
            )
            
            return (llmResponse.summary, llmResponse.title, folderSuggestion)
        } catch let error as LLMError {
            throw error
        } catch {
            print("Unexpected error: \(error)")
            throw LLMError.networkError(error)
        }
    }
}

// Response models
private struct OpenRouterResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

private struct OpenRouterErrorResponse: Codable {
    let error: Error
    
    struct Error: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

private struct LLMResponse: Codable {
    let summary: String
    let title: String
    let suggestedFolder: String?
    let shouldCreateNewFolder: Bool
    let newFolderName: String?
}

struct FolderSuggestion {
    let suggestedFolder: String?
    let shouldCreateNewFolder: Bool
    let newFolderName: String?
}
