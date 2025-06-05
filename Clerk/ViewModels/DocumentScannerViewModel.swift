import Vision
import Foundation
import UIKit
import Combine
import AVFoundation

final class DocumentScannerViewModel: ObservableObject {
    // Core components
    let cameraManager = CameraSessionManager()
    private let processor = DocumentProcessor()

    // Published properties for the SwiftUI view
    @Published var detectedCorners: [CGPoint]? = nil
    @Published var isTorchOn: Bool = false
    @Published var isCapturing: Bool = false
    @Published var finalScannedImage: UIImage? = nil

    private var frameCancellable: AnyCancellable?

    init() {
        subscribeToCameraFrames()
    }

    private func subscribeToCameraFrames() {
        frameCancellable = cameraManager.framePublisher
            .sink { [weak self] (sampleBuffer: CMSampleBuffer) in
                guard let self = self,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                self.processor.detectDocument(in: pixelBuffer) { corners in
                    DispatchQueue.main.async {
                        self.detectedCorners = corners
                    }
                }
            }
    }

    func startSession() {
        cameraManager.startSession()
    }

    func stopSession() {
        cameraManager.stopSession()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        cameraManager.toggleTorch()
    }

    func captureDocument() {
        guard !isCapturing else { return }
        isCapturing = true

        // Freeze the last known corners
        let cornersToUse = detectedCorners

        cameraManager.capturePhoto { [weak self] result in
            DispatchQueue.global(qos: .userInitiated).async {
                switch result {
                case .success(let data):
                    guard let self = self,
                          let image = UIImage(data: data),
                          let cgImage = image.cgImage else {
                        DispatchQueue.main.async { self?.isCapturing = false }
                        return
                    }

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    let request = VNDetectRectanglesRequest { request, error in
                        var scannedImage: UIImage? = nil

                        defer {
                            DispatchQueue.main.async {
                                self.finalScannedImage = scannedImage
                                self.isCapturing = false
                            }
                        }

                        guard error == nil,
                              let results = request.results as? [VNRectangleObservation],
                              let rect = results.first else {
                            scannedImage = image // fallback
                            return
                        }

                        let corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
                        scannedImage = self.processor.applyPerspectiveCorrection(to: data, with: corners)
                    }

                    request.minimumAspectRatio = 0.3
                    request.quadratureTolerance = 30.0

                    try? handler.perform([request])

                case .failure(_):
                    DispatchQueue.main.async {
                        self?.isCapturing = false
                    }
                }
            }
        }
    }
}
