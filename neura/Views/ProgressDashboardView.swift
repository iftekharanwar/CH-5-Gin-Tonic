import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.dismiss) private var dismiss

    private let drawItems: [(imageName: String, word: String)] =
        DrawActivity.all.map { ($0.imageName, $0.word) }
    private let fillItems: [(imageName: String, word: String)] =
        WordPuzzle.all.map { ($0.modelName, $0.word) }

    @State private var appeared = false
    @State private var mascotSpeech: String? = nil
    @State private var showMascotSpeech = false

    private var allActivities: [(imageName: String, word: String, type: String, label: String)] {
        let draws = drawItems.map { ($0.imageName, $0.word, "draw", "Draw") }
        let fills = fillItems.map { ($0.imageName, $0.word, "fill", "Fill") }
        return draws + fills
    }

    private var totalDone: Int {
        allActivities.filter {
            AchievementStore.shared.isCompleted(activity: $0.imageName, type: $0.type)
        }.count
    }

    private var fillStars: Int { AchievementStore.shared.totalStars(type: "fill") }
    private var maxStars: Int { fillItems.count * 3 }

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
                        Text("MY PROGRESS")
                            .font(.app(size: min(minDim * 0.045, 30)))
                            .foregroundStyle(Color.appOrange)

                        HStack {
                            BackButton { dismiss() }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, geo.size.width * 0.03)
                    .padding(.top, max(geo.safeAreaInsets.top, geo.size.height * 0.04))
                    .padding(.bottom, geo.size.height * 0.015)

                    // Summary strip
                    summaryStrip(minDim: minDim)
                        .padding(.horizontal, geo.size.width * 0.05)
                        .padding(.bottom, geo.size.height * 0.015)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                    // Activity list
                    ScrollView {
                        VStack(spacing: minDim * 0.015) {
                            // Draw section
                            sectionHeader(title: "Draw", icon: "paintbrush.pointed.fill", color: Color(red: 0.90, green: 0.40, blue: 0.30), minDim: minDim)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.15), value: appeared)

                            ForEach(Array(drawItems.enumerated()), id: \.offset) { i, item in
                                let stars = AchievementStore.shared.getStars(activity: item.imageName, type: "draw")
                                activityRow(
                                    imageName: item.imageName,
                                    word: item.word,
                                    isDone: stars > 0,
                                    stars: 0,
                                    minDim: minDim
                                )
                                .opacity(appeared ? 1 : 0)
                                .offset(x: appeared ? 0 : -20)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.2 + Double(i) * 0.05), value: appeared)
                            }

                            Spacer().frame(height: minDim * 0.01)

                            // Fill section
                            sectionHeader(title: "Fill", icon: "textformat.abc", color: Color(red: 0.25, green: 0.52, blue: 0.85), minDim: minDim)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.4), value: appeared)

                            ForEach(Array(fillItems.enumerated()), id: \.offset) { i, item in
                                let stars = AchievementStore.shared.getStars(activity: item.imageName, type: "fill")
                                activityRow(
                                    imageName: item.imageName,
                                    word: item.word,
                                    isDone: stars > 0,
                                    stars: stars,
                                    minDim: minDim
                                )
                                .opacity(appeared ? 1 : 0)
                                .offset(x: appeared ? 0 : -20)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.45 + Double(i) * 0.05), value: appeared)
                            }
                        }
                        .padding(.horizontal, geo.size.width * 0.05)
                        .padding(.bottom, geo.size.height * 0.12)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Mascot bottom-right
                let mascotSize = minDim * 0.16
                MascotView(
                    size: mascotSize,
                    speechText: mascotSpeech,
                    showSpeech: showMascotSpeech,
                    tailDirection: .right,
                    bounce: 0
                )
                .position(
                    x: geo.size.width - mascotSize * 0.5,
                    y: geo.size.height - mascotSize * 0.25
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                mascotSpeech = funMessage()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    showMascotSpeech = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showMascotSpeech = false
                    }
                }
            }
        }
    }

    // MARK: - Summary Strip

    @ViewBuilder
    private func summaryStrip(minDim: CGFloat) -> some View {
        HStack(spacing: minDim * 0.04) {
            // Completed
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: min(minDim * 0.028, 18), weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.65, blue: 0.35))
                Text("\(totalDone)/\(allActivities.count) done")
                    .font(.system(size: min(minDim * 0.025, 16), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.28))
            }

            Spacer()

            // Stars
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: min(minDim * 0.028, 18), weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.10))
                Text("\(fillStars)/\(maxStars) stars")
                    .font(.system(size: min(minDim * 0.025, 16), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.28))
            }
        }
        .padding(.horizontal, minDim * 0.03)
        .padding(.vertical, minDim * 0.018)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.appCardBorder.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(title: String, icon: String, color: Color, minDim: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: min(minDim * 0.025, 16), weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.app(size: min(minDim * 0.03, 20)))
                .foregroundStyle(color)
            VStack { Divider() }
        }
        .padding(.top, minDim * 0.01)
    }

    // MARK: - Activity Row

    @ViewBuilder
    private func activityRow(imageName: String, word: String, isDone: Bool, stars: Int, minDim: CGFloat) -> some View {
        let rowH = min(minDim * 0.09, 58.0)

        HStack(spacing: minDim * 0.025) {
            // Thumbnail
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: rowH * 0.8, height: rowH * 0.8)
                .saturation(isDone ? 1.0 : 0.5)
                .opacity(isDone ? 1.0 : 0.6)

            // Name
            Text(word)
                .font(.app(size: min(minDim * 0.028, 18)))
                .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.22))

            Spacer()

            // Stars (fill activities only)
            if stars > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: min(minDim * 0.022, 14), weight: .bold))
                            .foregroundStyle(
                                i < stars
                                    ? Color(red: 1.0, green: 0.78, blue: 0.10)
                                    : Color(red: 0.82, green: 0.76, blue: 0.68)
                            )
                    }
                }
            }

            // Done badge
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: min(minDim * 0.028, 18), weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.65, blue: 0.35))
            } else {
                Circle()
                    .strokeBorder(Color(red: 0.80, green: 0.75, blue: 0.68), lineWidth: 1.5)
                    .frame(width: min(minDim * 0.028, 18), height: min(minDim * 0.028, 18))
            }
        }
        .padding(.horizontal, minDim * 0.025)
        .frame(height: rowH)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isDone ? 0.8 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDone
                        ? Color(red: 0.18, green: 0.65, blue: 0.35).opacity(0.3)
                        : Color.appCardBorder.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Fun Message

    private func funMessage() -> String {
        let allDone = totalDone >= allActivities.count
        if allDone && fillStars == maxStars {
            return "WOW! All perfect!"
        } else if allDone {
            return "You did it all!"
        } else if totalDone > allActivities.count / 2 {
            return "Almost there!"
        } else if totalDone > 0 {
            return "Great start!"
        } else {
            return "Let's go!"
        }
    }
}
