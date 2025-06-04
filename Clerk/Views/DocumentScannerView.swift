import SwiftUI

struct DocumentScannerView: View {
    @StateObject private var viewModel = DocumentScannerViewModel()
    @State private var showCornerEditor = false
    @State private var imageToEdit: UIImage? = nil

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
                    onReturn: { /* Future: navigate back */ }
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
                    onSave: { _ in
                        showCornerEditor = false
                    },
                    onCancel: {
                        showCornerEditor = false
                    }
                )
            }
        }
    }
}
