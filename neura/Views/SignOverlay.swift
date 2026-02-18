import SwiftUI
#if os(iOS)
import UIKit
#endif

// ─── Mirror of Signs.metal / Terrain.metal constants ─────────────────────────
// These must stay in sync with the Metal shaders. Swift replicates the same
// arithmetic so the overlay is always pixel-perfect on every screen size.

// Replicates hillHeight(x, layer) from Terrain.metal
private func hillHeight(_ x: CGFloat, layer: CGFloat) -> CGFloat {
    let f1 = 1.8 + layer * 0.4
    let f2 = 3.7 + layer * 0.9
    let f3 = 6.1 + layer * 1.3
    let p1 = layer * 1.57
    let p2 = layer * 2.94
    let p3 = layer * 4.11
    return sin(x * f1 + p1) * 0.09
         + sin(x * f2 + p2) * 0.05
         + sin(x * f3 + p3) * 0.03
}

// Shared ground anchor — both signs use sign 1's groundY so planks are level.
// Matches Signs.metal: h2 = h1 = 0.18 + hillHeight(cx1, 3.0)
private let sharedGroundY: CGFloat = 0.18 + hillHeight(0.28, layer: 3.0)

// Replicates the plank-center UV computed in drawSign() from Signs.metal.
private func plankCenterUV(cx: CGFloat, tilt: CGFloat) -> CGPoint {
    let postH: CGFloat = 0.24
    let plankCenterY   = sharedGroundY + postH * 0.88
    let plankCenterX   = cx + tilt * 0.02
    return CGPoint(x: plankCenterX, y: plankCenterY)
}

// Sign geometry constants — must match Signs.metal
private let plankUVW: CGFloat = 0.26
private let plankUVH: CGFloat = 0.09

// Tilt in radians (matches Signs.metal: -0.04 and +0.05)
// Converted to degrees for SwiftUI rotationEffect
private let sign1TiltRad: CGFloat = -0.04
private let sign2TiltRad: CGFloat =  0.05

// Navigation destinations
enum SignDestination: Hashable {
    case learnWords, letsDraw
}

struct SignOverlay: View {

    @Binding var navigateTo: SignDestination?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Compute plank centers in Metal UV space, then convert to SwiftUI points.
            // Metal UV: y=0 is bottom → SwiftUI: y=0 is top, so swiftUI_y = (1 − metalY) * height
            let uv1 = plankCenterUV(cx: 0.28, tilt: sign1TiltRad)
            let uv2 = plankCenterUV(cx: 0.72, tilt: sign2TiltRad)

            let x1 = uv1.x * w
            let y1 = (1.0 - uv1.y) * h
            let x2 = uv2.x * w
            let y2 = (1.0 - uv2.y) * h

            // Plank pixel size — same UV ratios as the shader, scaled to screen
            let pw = plankUVW * w
            let ph = plankUVH * h

            ZStack {
                signButton(
                    label: "Learn Words",
                    tiltDeg: Double(sign1TiltRad * 180 / .pi),
                    x: x1, y: y1,
                    pw: pw, ph: ph
                ) { navigateTo = .learnWords }

                signButton(
                    label: "Let's Draw",
                    tiltDeg: Double(sign2TiltRad * 180 / .pi),
                    x: x2, y: y2,
                    pw: pw, ph: ph
                ) { navigateTo = .letsDraw }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func signButton(
        label: String,
        tiltDeg: Double,
        x: CGFloat, y: CGFloat,
        pw: CGFloat, ph: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        SignButton(label: label, tiltDeg: tiltDeg, x: x, y: y, pw: pw, ph: ph, action: action)
    }
}

// Extracted so @State for press animation lives in its own view
private struct SignButton: View {
    let label: String
    let tiltDeg: Double
    let x: CGFloat
    let y: CGFloat
    let pw: CGFloat
    let ph: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.system(size: pw * 0.15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: pw, height: ph)
            .background(Color.clear)
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
            .rotationEffect(.degrees(tiltDeg))
            .position(x: x, y: y)
            .contentShape(Rectangle()
                .size(width: pw, height: ph)
                .offset(x: x - pw / 2, y: y - ph / 2)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}
