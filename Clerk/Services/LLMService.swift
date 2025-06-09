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
    
    static func analyzeDocument(images: [UIImage]) async throws -> (summary: String, title: String) {
        let apiURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        // Convert images to base64 strings
        let imageData = images.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
            return data.base64EncodedString()
        }
        
        guard !imageData.isEmpty else {
            throw LLMError.processingError
        }
        
        // Prepare the prompt for the LLM
        let prompt = """
        Analyze these document images and provide:
        1. A concise summary of the content
        2. A suitable title for the document
        
        Format your response as JSON with two fields:
        {
            "summary": "your summary here",
            "title": "your title here"
        }
        """
        
        // Prepare request body for OpenRouter
        let requestBody: [String: Any] = [
            "model": "mistralai/mistral-7b-instruct:free",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageData[0])"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Clerk/1.0", forHTTPHeaderField: "HTTP-Referer")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error serializing request body: \(error)")
            throw LLMError.processingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Print response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                if let errorResponse = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) {
                    throw LLMError.apiError(errorResponse.error.message)
                }
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let openRouterResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            
            // Parse the JSON response from the LLM
            guard let content = openRouterResponse.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8),
                  let llmResponse = try? JSONDecoder().decode(LLMResponse.self, from: jsonData) else {
                print("Failed to parse LLM response content: \(openRouterResponse.choices.first?.message.content ?? "nil")")
                throw LLMError.invalidResponse
            }
            
            return (llmResponse.summary, llmResponse.title)
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
}
