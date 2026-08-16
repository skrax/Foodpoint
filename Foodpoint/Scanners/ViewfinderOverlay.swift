import SwiftUI

/// Dims the camera preview outside a rectangular cutout and draws a pulsing
/// corner reticle inside it, guiding the user to align a barcode.
/// Purely decorative — overlaid on top of `FastFoodBarcodeScanner`.
struct ViewfinderOverlay: View {
    // 🎨 Styling parameters
    let backgroundOpacity: Double = 0.65
    let cutoutSize = CGSize(width: 280, height: 180) // Ideal size for 1D barcodes
    let cutoutCornerRadius: CGFloat = 12
    let reticleColor: Color = .green
    let reticleLineWidth: CGFloat = 4

    @State private var reticlePulse: CGFloat = 1.0 // for animation

    var body: some View {
        ZStack {
            // LAYER 1: The background dimming layer and the cutout geometry
            // Using a Color and blending it creates the transparent mask effect.
            Group {
                // The semi-transparent overlay
                Color.black.opacity(backgroundOpacity)
                
                // The solid shape used to carve the cutout
                RoundedRectangle(cornerRadius: cutoutCornerRadius)
                    .frame(width: cutoutSize.width, height: cutoutSize.height)
                    .blendMode(.destinationOut) // ✂️ MAGIC HACK: Carves hole in the parent background
            }
            // All composite operations MUST happen inside a single layer/modifier group
            // We use .compositingGroup() to ensure the blend mode affects the ZStack contents, not the view behind it.
            .compositingGroup()

            // LAYER 2: The UI visual feedback elements (not clipped)
            ZStack {
                // The main corner reticle shape
                ReticleShape(cornerLength: 25, lineWidth: reticleLineWidth)
                    .stroke(reticleColor, style: StrokeStyle(lineWidth: reticleLineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: cutoutSize.width, height: cutoutSize.height)
                    // Optional subtle pulse animation
                    .scaleEffect(reticlePulse)
                    .opacity(reticlePulse)

                // Optional instructional text
                Text("Align Food Barcode Inside")
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .padding(10)
                    .background(Color.black.opacity(0.5).cornerRadius(8))
                    .offset(y: (cutoutSize.height / 2) + 40)
            }
            .ignoresSafeArea() // Ensure overlay fills full screen
        }
        .onAppear {
            // Subtle, continuous pulsing animation when the overlay is shown
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                reticlePulse = 1.025
            }
        }
    }
}
