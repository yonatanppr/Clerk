import UIKit
import Foundation
import Vision
import CoreImage

final class DocumentProcessor {
    private let visionQueue = DispatchQueue(label: "visionQueue")

    /// Detect document rectangle in a video frame.
    func detectDocument(in pixelBuffer: CVPixelBuffer,
                        completion: @escaping ([CGPoint]?) -> Void) {
        let request = VNDetectRectanglesRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRectangleObservation],
                  let rect = observations.first else {
                completion(nil)
                return
            }
            // VNRectangleObservation returns normalized points in image coordinate space
            let corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
            completion(corners)
        }
        request.minimumAspectRatio = 0.3
        request.quadratureTolerance = 30.0

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        visionQueue.async {
            try? handler.perform([request])
        }
    }

    /// Apply perspective correction on captured image data using the four corners.
    func applyPerspectiveCorrection(to imageData: Data, with corners: [CGPoint]) -> UIImage? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage
        else { return nil }

        // Convert normalized corners (0–1) to pixel coordinates
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let pixelCorners = corners.map { CGPoint(x: $0.x * width, y: (1 - $0.y) * height) } // flip Y if needed

        // Build a CIImage from cgImage
        let ciImage = CIImage(cgImage: cgImage)

        // Create perspective transform filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)

        // Assign corners: topLeft, topRight, bottomRight, bottomLeft
        filter.setValue(CIVector(cgPoint: pixelCorners[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: pixelCorners[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: pixelCorners[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: pixelCorners[3]), forKey: "inputBottomLeft")

        guard let outputCI = filter.outputImage else { return nil }
        let context = CIContext()
        if let outputCG = context.createCGImage(outputCI, from: outputCI.extent) {
            return UIImage(cgImage: outputCG, scale: uiImage.scale, orientation: uiImage.imageOrientation)
        }
        return nil
    }
}
