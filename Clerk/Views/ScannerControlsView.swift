import SwiftUI

struct ScannerControlsView: View {
    let isTorchOn: Bool
    let isCapturing: Bool

    let onCapture: () -> Void
    let onToggleTorch: () -> Void
    let onReturn: () -> Void

    var body: some View {
        HStack(spacing: 60) {
            // Return button (no action for now)
            Button(action: onReturn) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .foregroundColor(.white)

            // Capture button
            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    if isCapturing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .disabled(isCapturing)

            // Torch button
            Button(action: onToggleTorch) {
                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .foregroundColor(.white)
        }
    }
}
