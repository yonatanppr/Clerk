import SwiftUI

struct DocumentOverlayView: View {
    /// Four corners in normalized (0…1) coordinate space, with origin at top-left
    let corners: [CGPoint]

    var body: some View {
        GeometryReader { geo in
            if corners.count == 4 {
                Path { path in
                    // Map normalized points → actual view points
                    let pts = corners.map { CGPoint(x: $0.x * geo.size.width,
                                                    y: (1 - $0.y) * geo.size.height) }
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.addLine(to: pts[3])
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .background(
                    Color.white.opacity(0.2)
                        .blendMode(.multiply)
                        .mask(
                            Path { path in
                                let pts = corners.map { CGPoint(x: $0.x * geo.size.width,
                                                                y: (1 - $0.y) * geo.size.height) }
                                path.move(to: pts[0])
                                path.addLine(to: pts[1])
                                path.addLine(to: pts[2])
                                path.addLine(to: pts[3])
                                path.closeSubpath()
                            }
                            .fill(style: FillStyle(eoFill: true))
                        )
                )
                .animation(.easeInOut(duration: 0.1), value: corners)
            }
        }
        .allowsHitTesting(false) // so taps pass through to buttons below
    }
}
