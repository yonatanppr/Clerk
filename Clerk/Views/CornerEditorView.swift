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
    @State private var selectedCorner: Int? = nil
    @State private var isDragging = false
    @State private var showGrid = true
    
    // Constants for UI
    private let cornerSize: CGFloat = 24
    private let gridOpacity: Double = 0.3
    private let cornerColor = Color.blue
    private let selectedCornerColor = Color.yellow
    private let gridColor = Color.white.opacity(0.5)
    
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
            displayHeight = displayWidth / imageAspectRatio
        } else {
            displayHeight = viewSize.height
            displayWidth = displayHeight * imageAspectRatio
        }

        return CGRect(
            x: (viewSize.width - displayWidth) / 2,
            y: (viewSize.height - displayHeight) / 2,
            width: displayWidth,
            height: displayHeight
        )
    }
    
    private func cornerPosition(for index: Int, in frame: CGRect) -> CGPoint {
        let imageSize = originalImage.size
        return CGPoint(
            x: frame.origin.x + adjustedCorners[index].x / imageSize.width * frame.size.width,
            y: frame.origin.y + adjustedCorners[index].y / imageSize.height * frame.size.height
        )
    }
    
    private func updateCorner(_ index: Int, with location: CGPoint, in frame: CGRect) {
        let imageSize = originalImage.size
        let relative = CGPoint(
            x: (location.x - frame.origin.x) / frame.size.width,
            y: (location.y - frame.origin.y) / frame.size.height
        )
        
        // Constrain to image bounds
        let constrainedX = max(0, min(1, relative.x))
        let constrainedY = max(0, min(1, relative.y))
        
        adjustedCorners[index] = CGPoint(
            x: constrainedX * imageSize.width,
            y: constrainedY * imageSize.height
        )
    }

    var body: some View {
        GeometryReader { geo in
            let imageFrame = computeImageFrame(for: geo.size)
            
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Image
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                
                // Grid overlay
                if showGrid {
                    GridOverlay(frame: imageFrame)
                        .stroke(gridColor, lineWidth: 1)
                }
                
                // Document outline
                Path { path in
                    let pts = adjustedCorners.indices.map { cornerPosition(for: $0, in: imageFrame) }
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.addLine(to: pts[3])
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                
                // Corner handles
                ForEach(adjustedCorners.indices, id: \.self) { index in
                    CornerHandle(
                        position: cornerPosition(for: index, in: imageFrame),
                        isSelected: selectedCorner == index,
                        size: cornerSize,
                        color: selectedCorner == index ? selectedCornerColor : cornerColor
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                selectedCorner = index
                                isDragging = true
                                updateCorner(index, with: value.location, in: imageFrame)
                            }
                            .onEnded { _ in
                                isDragging = false
                                selectedCorner = nil
                            }
                    )
                }
                
                // Controls
                VStack {
                    HStack {
                        Button(action: { showGrid.toggle() }) {
                            Image(systemName: showGrid ? "grid" : "grid.circle")
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Preview") {
                            if let processed = applyCorrection() {
                                previewImage = processed
                                showPreview = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            PreviewView(
                image: previewImage,
                onSave: { onSave(adjustedCorners) },
                onCancel: { showPreview = false }
            )
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

// MARK: - Supporting Views

struct CornerHandle: View {
    let position: CGPoint
    let isSelected: Bool
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(radius: isSelected ? 4 : 2)
            .position(position)
    }
}

struct GridOverlay: Shape {
    let frame: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical lines
        for i in 1...2 {
            let x = frame.minX + frame.width * CGFloat(i) / 3
            path.move(to: CGPoint(x: x, y: frame.minY))
            path.addLine(to: CGPoint(x: x, y: frame.maxY))
        }
        
        // Horizontal lines
        for i in 1...2 {
            let y = frame.minY + frame.height * CGFloat(i) / 3
            path.move(to: CGPoint(x: frame.minX, y: y))
            path.addLine(to: CGPoint(x: frame.maxX, y: y))
        }
        
        return path
    }
}

struct PreviewView: View {
    let image: UIImage?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
