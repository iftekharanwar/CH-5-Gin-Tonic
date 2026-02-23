import SwiftUI

// MARK: - Activity Type

enum ActivityType: String, Hashable {
    case draw, fill

    var title: String {
        switch self {
        case .draw: return "DRAW"
        case .fill: return "FILL"
        }
    }
}

// MARK: - ActivityGridView

struct ActivityGridView: View {
    let activityType: ActivityType
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = WordSpeaker()

    @State private var selectedIndex: Int? = nil
    @State private var appeared = false
    @State private var refreshID = UUID()

    private var items: [(imageName: String, word: String)] {
        switch activityType {
        case .draw:
            return DrawActivity.all.map { ($0.imageName, $0.word) }
        case .fill:
            return WordPuzzle.all.map { ($0.modelName, $0.word) }
        }
    }

    private var allCompleted: Bool {
        items.indices.allSatisfy { i in
            AchievementStore.shared.isCompleted(activity: items[i].imageName, type: activityType.rawValue)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let isLand = geo.size.width > geo.size.height

            ZStack {
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    // Top bar
                    ZStack {
                        Text(activityType.title)
                            .font(.app(size: min(minDim * 0.05, 32)))
                            .foregroundStyle(Color.appOrange)

                        HStack {
                            BackButton { dismiss() }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, geo.size.width * 0.03)
                    .padding(.top, max(geo.safeAreaInsets.top, geo.size.height * 0.04))
                    .padding(.bottom, geo.size.height * 0.01)

                    // Completion summary
                    if allCompleted {
                        Text("All Done!")
                            .font(.app(size: min(minDim * 0.022, 16)))
                            .foregroundStyle(Color(red: 0.18, green: 0.65, blue: 0.35))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color(red: 0.18, green: 0.65, blue: 0.35).opacity(0.15))
                            )
                            .padding(.bottom, geo.size.height * 0.015)
                    }

                    // Grid
                    let columns = Array(repeating: GridItem(
                        .flexible(),
                        spacing: isLand ? geo.size.width * 0.025 : minDim * 0.03
                    ), count: isLand ? 4 : 3)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: minDim * 0.03) {
                            ForEach(items.indices, id: \.self) { i in
                                let item = items[i]
                                let stars = AchievementStore.shared.getStars(
                                    activity: item.imageName,
                                    type: activityType.rawValue
                                )
                                ActivityGridCell(
                                    imageName: item.imageName,
                                    word: item.word,
                                    isCompleted: stars > 0,
                                    cellSize: isLand
                                        ? min(geo.size.width * 0.19, 180)
                                        : min(geo.size.width * 0.27, 200),
                                    delay: Double(i) * 0.06
                                ) {
                                    SoundPlayer.shared.play(.tap)
                                    speaker.speak(item.word)
                                    selectedIndex = i
                                }
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.7)
                                .animation(
                                    .spring(response: 0.45, dampingFraction: 0.7).delay(Double(i) * 0.06),
                                    value: appeared
                                )
                            }
                        }
                        .padding(.horizontal, geo.size.width * 0.05)
                        .padding(.top, 10)
                        .padding(.bottom, geo.size.height * 0.04)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .id(refreshID)
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            refreshID = UUID()
            // Re-trigger staggered entry when returning from an activity
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { appeared = true }
            }
        }
        .navigationDestination(item: $selectedIndex) { index in
            switch activityType {
            case .draw:
                LetsDrawView(startIndex: index)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .fill:
                LearnWordsView(startIndex: index)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Grid Cell

private struct ActivityGridCell: View {
    let imageName: String
    let word: String
    let isCompleted: Bool
    let cellSize: CGFloat
    let delay: Double
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: cellSize * 0.06) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: cellSize * 0.55, height: cellSize * 0.55)
                    .saturation(isCompleted ? 1.0 : 0.7)
                    .opacity(isCompleted ? 1.0 : 0.8)

                Text(word)
                    .font(.app(size: cellSize * 0.13))
                    .foregroundStyle(Color(red: 0.35, green: 0.30, blue: 0.25))
            }
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: cellSize * 0.12, style: .continuous)
                    .fill(Color.white.opacity(isCompleted ? 0.85 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cellSize * 0.12, style: .continuous)
                    .strokeBorder(
                        isCompleted
                        ? Color(red: 0.18, green: 0.65, blue: 0.35).opacity(0.5)
                        : Color.appCardBorder.opacity(0.5),
                        lineWidth: isCompleted ? 2 : 1.5
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: cellSize * 0.14, weight: .bold))
                        .foregroundStyle(Color(red: 0.18, green: 0.65, blue: 0.35))
                        .background(Circle().fill(Color.white).padding(2))
                        .offset(x: cellSize * 0.04, y: -cellSize * 0.04)
                }
            }
            .shadow(color: Color.appCardBorder.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    }
                }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel("\(word). \(isCompleted ? "Completed" : "Not completed")")
        .accessibilityHint("Double tap to start this activity")
    }
}
