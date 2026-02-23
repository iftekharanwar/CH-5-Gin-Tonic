import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Kid-friendly back button matching the app's orange colour scheme.
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
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.608, blue: 0.0))
                    .shadow(color: Color(red: 1.0, green: 0.50, blue: 0.0).opacity(0.35), radius: 4, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
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
        .accessibilityLabel("Go back")
        .accessibilityHint("Returns to the previous screen")
    }
}
