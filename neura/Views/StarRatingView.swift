import SwiftUI

// MARK: - StarRatingView

struct StarRatingView: View {
    let stars: Int
    var size: CGFloat = 36
    var animated: Bool = true

    @State private var appeared = false

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(
                        i < stars
                        ? Color(red: 1.0, green: 0.78, blue: 0.10)
                        : Color.gray.opacity(0.35)
                    )
                    .shadow(color: i < stars ? Color(red: 1.0, green: 0.78, blue: 0.10).opacity(0.5) : .clear,
                            radius: 6, x: 0, y: 2)
                    .scaleEffect(appeared || !animated ? 1.0 : 0.3)
                    .opacity(appeared || !animated ? 1.0 : 0)
                    .animation(
                        animated
                        ? .spring(response: 0.45, dampingFraction: 0.55).delay(Double(i) * 0.18)
                        : .none,
                        value: appeared
                    )
            }
        }
        .onAppear {
            if animated { appeared = true }
        }
    }
}
