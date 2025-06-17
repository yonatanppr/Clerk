import UIKit
import Vision

struct OCRService {
    static func recognizeText(from images: [UIImage]) throws -> String {
        var fullText = ""
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            if let observations = request.results as? [VNRecognizedTextObservation] {
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        fullText += candidate.string + "\n"
                    }
                }
            }
        }
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
