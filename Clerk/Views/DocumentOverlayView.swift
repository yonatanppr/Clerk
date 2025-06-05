import SwiftUI

struct DocumentOverlayView: View {
    /// Four corners in normalized (0…1) coordinate space, with origin at top-left
    let corners: [CGPoint]
    @State private var showGuidance = true
    
    // Constants for UI
    private let guidanceOpacity: Double = 0.7
    private let guidanceText = "Position document within frame"
    private let guidanceFont = Font.system(size: 18, weight: .medium)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                if corners.count == 4 {
                    // Document outline
                    DocumentOutline(corners: corners, size: geo.size)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .background(
                            Color.white.opacity(0.2)
                                .blendMode(.multiply)
                                .mask(DocumentOutline(corners: corners, size: geo.size))
                        )
                    
                    // Corner indicators
                    ForEach(0..<4) { index in
                        CornerIndicator(
                            position: cornerPosition(for: index, in: geo.size),
                            isTop: index < 2
                        )
                    }
                    
                    // Guidance text
                    if showGuidance {
                        VStack {
                            Text(guidanceText)
                                .font(guidanceFont)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(guidanceOpacity))
                                .cornerRadius(10)
                                .padding(.top, 50)
                            Spacer()
                        }
                    }
                }
            }
            .onAppear {
                // Hide guidance after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showGuidance = false
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        let corner = corners[index]
        return CGPoint(
            x: corner.x * size.width,
            y: (1 - corner.y) * size.height
        )
    }
}

// MARK: - Supporting Views

struct DocumentOutline: Shape {
    let corners: [CGPoint]
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pts = corners.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
        
        path.move(to: pts[0])
        path.addLine(to: pts[1])
        path.addLine(to: pts[2])
        path.addLine(to: pts[3])
        path.closeSubpath()
        
        return path
    }
}

struct CornerIndicator: View {
    let position: CGPoint
    let isTop: Bool
    
    private let size: CGFloat = 20
    private let lineWidth: CGFloat = 3
    
    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: lineWidth)
                .position(x: position.x, y: position.y)
            
            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: lineWidth, height: size)
                .position(x: position.x, y: position.y)
        }
    }
}
