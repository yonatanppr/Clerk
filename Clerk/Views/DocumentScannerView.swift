import SwiftUI

struct DocumentScannerView: View {
    @StateObject private var viewModel = DocumentScannerViewModel()
    @State private var showCornerEditor = false
    @Environment(\.dismiss) private var dismiss // Add dismiss environment action
    @State private var imageToEdit: UIImage? = nil
    let onSave: (Data) -> Void

    var body: some View {
        ZStack {
            // 1. LIVE CAMERA FEED
            CameraPreview(session: viewModel.cameraManager.session)
                .ignoresSafeArea()

            // 2. EDGE OVERLAY (if available)
            if let corners = viewModel.detectedCorners {
                DocumentOverlayView(corners: corners)
                    .ignoresSafeArea()
            }

            // 3. CONTROLS AT BOTTOM
            VStack {
                Spacer()
                ScannerControlsView(
                    isTorchOn: viewModel.isTorchOn,
                    isCapturing: viewModel.isCapturing,
                    onCapture: { viewModel.captureDocument() },
                    onToggleTorch: { viewModel.toggleTorch() },
                    onReturn: { dismiss() } // Call dismiss when onReturn is triggered
                )
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.finalScannedImage != nil },
            set: { if !$0 { viewModel.finalScannedImage = nil } }
        )) {
            if let scannedImage = viewModel.finalScannedImage {
                VStack {
                    Image(uiImage: scannedImage)
                        .resizable()
                        .scaledToFit()
                    HStack {
                        Button("Dismiss") {
                            viewModel.finalScannedImage = nil
                        }
                        Spacer()
                        Button("Save") {
                            if let imageData = scannedImage.jpegData(compressionQuality: 0.8) {
                                onSave(imageData)
                                dismiss()
                            }
                        }
                        Spacer()
                        Button("Edit Corners") {
                            imageToEdit = scannedImage
                            viewModel.finalScannedImage = nil
                            showCornerEditor = true
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }

        .sheet(isPresented: $showCornerEditor) {
            if let image = imageToEdit {
                CornerEditorView(
                    originalImage: image,
                    initialCorners: [
                        CGPoint(x: 0, y: 0),
                        CGPoint(x: image.size.width, y: 0),
                        CGPoint(x: image.size.width, y: image.size.height),
                        CGPoint(x: 0, y: image.size.height)
                    ],
                    onSave: { corners in
                        if let correctedImage = applyCorrection(to: image, with: corners),
                           let imageData = correctedImage.jpegData(compressionQuality: 0.8) {
                            onSave(imageData)
                            dismiss()
                        }
                        showCornerEditor = false
                    },
                    onCancel: {
                        showCornerEditor = false
                    }
                )
            }
        }
    }
    
    private func applyCorrection(to image: UIImage, with corners: [CGPoint]) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        
        let imgSize = image.size
        let pts = corners.map { CGPoint(x: $0.x, y: imgSize.height - $0.y) }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: pts[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: pts[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: pts[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: pts[3]), forKey: "inputBottomLeft")
        
        guard let outputCI = filter.outputImage else { return nil }
        let context = CIContext()
        if let outputCG = context.createCGImage(outputCI, from: outputCI.extent) {
            return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
        }
        return nil
    }
}
