import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Chunky wooden arrow button for kids — sits top-left of any destination view.
struct BackButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            // handled by gesture below
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .black))
                Text("Back")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.52, green: 0.30, blue: 0.10))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(red: 0.28, green: 0.14, blue: 0.04), lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
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
