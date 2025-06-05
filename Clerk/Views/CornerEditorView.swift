import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct CornerEditorView: View {
    let originalImage: UIImage
    let initialCorners: [CGPoint]
    let onSave: ([CGPoint]) -> Void
    let onCancel: () -> Void

    @State private var adjustedCorners: [CGPoint]
    @State private var previewImage: UIImage? = nil
    @State private var showPreview = false

    init(originalImage: UIImage,
         initialCorners: [CGPoint],
         onSave: @escaping ([CGPoint]) -> Void,
         onCancel: @escaping () -> Void) {
        self.originalImage = originalImage
        self.initialCorners = initialCorners
        self.onSave = onSave
        self.onCancel = onCancel
        _adjustedCorners = State(initialValue: initialCorners)
    }
    
    private func computeImageFrame(for geoSize: CGSize) -> CGRect {
        let imageSize = originalImage.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let viewSize = geoSize

        let displayWidth: CGFloat
        let displayHeight: CGFloat
        if viewSize.width / imageAspectRatio <= viewSize.height {
            displayWidth = viewSize.width
            displayHeight = viewSize.width / imageAspectRatio
        } else {
            displayHeight = viewSize.height
            displayWidth = viewSize.height * imageAspectRatio
        }

        return CGRect(
            x: (viewSize.width - displayWidth) / 2,
            y: (viewSize.height - displayHeight) / 2,
            width: displayWidth,
            height: displayHeight
        )
    }

    var body: some View {
        GeometryReader { geo in
            let imageFrame = computeImageFrame(for: geo.size)
            let imageSize = originalImage.size
            
            ZStack {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                Path { path in
                    guard adjustedCorners.count == 4 else { return }
                    let pts = adjustedCorners.map {
                        CGPoint(
                            x: imageFrame.origin.x + $0.x / imageSize.width * imageFrame.size.width,
                            y: imageFrame.origin.y + $0.y / imageSize.height * imageFrame.size.height
                        )
                    }
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.addLine(to: pts[3])
                    path.closeSubpath()
                }
                .stroke(Color.yellow, lineWidth: 2)

                ForEach(adjustedCorners.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .position(
                            x: imageFrame.origin.x + adjustedCorners[i].x / imageSize.width * imageFrame.size.width,
                            y: imageFrame.origin.y + adjustedCorners[i].y / imageSize.height * imageFrame.size.height
                        )
                        .gesture(
                            DragGesture().onChanged { value in
                                let relative = CGPoint(
                                    x: (value.location.x - imageFrame.origin.x) / imageFrame.size.width,
                                    y: (value.location.y - imageFrame.origin.y) / imageFrame.size.height
                                )
                                adjustedCorners[i] = CGPoint(x: relative.x * imageSize.width,
                                                             y: relative.y * imageSize.height)
                            }
                        )
                }

                VStack {
                    Spacer()
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .padding()
                        Spacer()
                        Button("Save Scan") {
                            if let processed = applyCorrection() {
                                previewImage = processed
                                showPreview = true
                            }
                        }
                        .padding()
                    }
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: $showPreview) {
                VStack {
                    if let img = previewImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    }
                    HStack {
                        Button("Cancel") {
                            showPreview = false
                        }
                        .padding()
                        Spacer()
                        Button("Confirm Save") {
                            if let img = previewImage {
                                onSave(adjustedCorners)
                            }
                            showPreview = false
                        }
                        .padding()
                    }
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                }
                .padding()
            }
        }
    }

    private func applyCorrection() -> UIImage? {
        guard let cgImage = originalImage.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }

        let imgSize = originalImage.size
        let pts = adjustedCorners.map { CGPoint(x: $0.x, y: imgSize.height - $0.y) }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: pts[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: pts[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: pts[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: pts[3]), forKey: "inputBottomLeft")

        guard let outputCI = filter.outputImage else { return nil }
        let context = CIContext()
        if let outputCG = context.createCGImage(outputCI, from: outputCI.extent) {
            return UIImage(cgImage: outputCG, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        }
        return nil
    }
}
