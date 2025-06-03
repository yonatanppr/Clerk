import SwiftUI

struct CornerEditorView: View {
    let originalImage: UIImage
    let initialCorners: [CGPoint]
    let onSave: ([CGPoint]) -> Void
    let onCancel: () -> Void

    @State private var adjustedCorners: [CGPoint]

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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                Path { path in
                    guard adjustedCorners.count == 4 else { return }
                    path.move(to: adjustedCorners[0])
                    path.addLine(to: adjustedCorners[1])
                    path.addLine(to: adjustedCorners[2])
                    path.addLine(to: adjustedCorners[3])
                    path.closeSubpath()
                }
                .stroke(Color.yellow, lineWidth: 2)

                ForEach(adjustedCorners.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .position(adjustedCorners[i])
                        .gesture(
                            DragGesture().onChanged { value in
                                adjustedCorners[i] = value.location
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
                            onSave(adjustedCorners)
                        }
                        .padding()
                    }
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}
