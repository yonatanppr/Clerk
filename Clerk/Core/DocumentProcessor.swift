import UIKit
import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

final class DocumentProcessor {
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private let context = CIContext()
    
    // Constants for document detection
    private let minimumAspectRatio: CGFloat = 0.3
    private let quadratureTolerance: CGFloat = 20.0
    private let minimumSize: CGFloat = 0.2
    private let maximumAspectRatio: CGFloat = 0.8
    
    /// Detect document rectangle in a video frame with enhanced accuracy
    func detectDocument(in pixelBuffer: CVPixelBuffer,
                       completion: @escaping ([CGPoint]?) -> Void) {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let observations = request.results as? [VNRectangleObservation],
                  let rect = observations.first else {
                completion(nil)
                return
            }
            
            // Apply additional validation
            guard self.isValidDocument(rect) else {
                completion(nil)
                return
            }
            
            // Get corners and apply smoothing
            let corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
            let smoothedCorners = self.smoothCorners(corners)
            completion(smoothedCorners)
        }
        
        // Configure request parameters for better accuracy
        request.minimumAspectRatio = Float(minimumAspectRatio)
        request.maximumAspectRatio = Float(maximumAspectRatio)
        request.quadratureTolerance = Float(quadratureTolerance)
        request.minimumSize = Float(minimumSize)
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        visionQueue.async {
            try? handler.perform([request])
        }
    }
    
    /// Apply perspective correction and image enhancement
    func applyPerspectiveCorrection(to imageData: Data, with corners: [CGPoint]) -> UIImage? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { return nil }
        
        // Convert normalized corners to pixel coordinates
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let pixelCorners = corners.map { CGPoint(x: $0.x * width, y: $0.y * height) }
        
        // Create CIImage
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply perspective correction
        guard let perspectiveImage = applyPerspectiveTransform(to: ciImage, with: pixelCorners) else {
            return nil
        }
        
        // Apply image enhancements
        let enhancedImage = enhanceImage(perspectiveImage)
        
        // Convert back to UIImage
        if let outputCG = context.createCGImage(enhancedImage, from: enhancedImage.extent) {
            return UIImage(cgImage: outputCG, scale: uiImage.scale, orientation: uiImage.imageOrientation)
        }
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func isValidDocument(_ rect: VNRectangleObservation) -> Bool {
        // Check if the rectangle is reasonably rectangular
        let aspectRatio = rect.boundingBox.width / rect.boundingBox.height
        guard aspectRatio >= minimumAspectRatio && aspectRatio <= maximumAspectRatio else {
            return false
        }
        
        // Check if the rectangle is large enough
        let size = rect.boundingBox.width * rect.boundingBox.height
        guard size >= minimumSize else {
            return false
        }
        
        return true
    }
    
    private func smoothCorners(_ corners: [CGPoint]) -> [CGPoint] {
        // Apply simple moving average smoothing to reduce jitter
        let smoothingFactor: CGFloat = 0.3
        return corners.map { corner in
            CGPoint(
                x: corner.x * (1 - smoothingFactor) + corner.x * smoothingFactor,
                y: corner.y * (1 - smoothingFactor) + corner.y * smoothingFactor
            )
        }
    }
    
    private func applyPerspectiveTransform(to image: CIImage, with corners: [CGPoint]) -> CIImage? {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: corners[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: corners[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: corners[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: corners[3]), forKey: "inputBottomLeft")
        
        return filter.outputImage
    }
    
    private func enhanceImage(_ image: CIImage) -> CIImage {
        var enhancedImage = image
        
        // Apply auto-enhancement filters
        let filters: [(CIImage) -> CIImage] = [
            applyContrastEnhancement,
            applySharpening,
            applyColorCorrection
        ]
        
        for filter in filters {
            enhancedImage = filter(enhancedImage)
        }
        
        return enhancedImage
    }
    
    private func applyContrastEnhancement(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey) // Slightly increase contrast
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)
        filter.setValue(1.0, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }
    
    private func applySharpening(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.4, forKey: kCIInputSharpnessKey) // Moderate sharpening
        return filter.outputImage ?? image
    }
    
    private func applyColorCorrection(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }
}
