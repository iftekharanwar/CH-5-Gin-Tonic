import SwiftUI
#if os(iOS)
import UIKit
import RealityKit
import Combine
#endif

// MARK: - Drag state

private struct DragState {
    var letter:     Character
    var color:      Color
    var position:   CGPoint
    var tileSize:   CGFloat
}

// MARK: - LearnWordsView

struct LearnWordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = WordSpeaker()

    @AppStorage("fillCompletedCount") private var savedCount = 0
    @State private var currentIndex  = 0
    @State private var puzzleState: PuzzleState = .idle
    @State private var isRevealed    = false
    @State private var completedCount = 0
    @State private var showAllDone   = false
    @State private var showReward    = false

    @State private var drag: DragState? = nil
    @State private var slotFrame: CGRect = .zero
    @State private var slotHighlighted = false
    @State private var bankLetters: [Character] = []

    @State private var mascotVisible = false
    @State private var mascotBounce: CGFloat = 0
    @State private var mascotSpeech: String? = nil
    @State private var showMascotSpeech = false
    @State private var wrongCount = 0
    @State private var earnedStars = 0
    @State private var sparkleOrigin: CGPoint? = nil

    private var puzzle: WordPuzzle { WordPuzzle.all[currentIndex] }
    private var isLastWord: Bool { currentIndex == WordPuzzle.all.count - 1 }

    private static func makeBankLetters(for puzzle: WordPuzzle) -> [Character] {
        let correct = puzzle.missingLetter
        let pool: [Character] = ["A", "E", "I", "O", "U", "B", "D", "R", "T", "N", "S", "P"]
        var result = pool.filter { $0 != correct }.shuffled().prefix(7).map { $0 }
        result.append(correct)
        return result.shuffled()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)

                if showReward {
                    FillRewardView(
                        word: puzzle.word,
                        imageName: puzzle.modelName,
                        modelName: puzzle.modelName,
                        stars: earnedStars,
                        geo: geo,
                        isLastWord: isLastWord
                    ) {
                        advanceWord()
                    }
                    .transition(.opacity)
                    .zIndex(2)
                } else {
                    let minDim = min(geo.size.width, geo.size.height)
                    let isLand = geo.size.width > geo.size.height
                    VStack(spacing: 0) {
                        topBar(geo: geo)

                        Spacer(minLength: geo.size.height * 0.01)

                        Image(puzzle.modelName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(
                                isLand ? geo.size.height * 0.26 : geo.size.height * 0.18,
                                minDim * 0.28
                            ))

                        Spacer(minLength: geo.size.height * 0.02)

                        wordRow(geo: geo)

                        Spacer(minLength: geo.size.height * 0.02)

                        Text(isRevealed ? "AMAZING!" : "DRAG THE MISSING LETTER!")
                            .font(.app(size: min(minDim * 0.028, 20)))
                            .foregroundStyle(
                                isRevealed
                                ? Color(red: 0.18, green: 0.62, blue: 0.32)
                                : Color(red: 0.55, green: 0.42, blue: 0.28)
                            )
                            .animation(.easeInOut(duration: 0.25), value: isRevealed)
                            .padding(.bottom, geo.size.height * 0.01)

                        letterBank(geo: geo)
                            .padding(.bottom, geo.size.height * 0.01)

                        Spacer(minLength: geo.size.height * 0.01)
                    }
                }

                if mascotVisible && !showReward && !showAllDone {
                    let minDim2 = min(geo.size.width, geo.size.height)
                    let starSize = minDim2 * 0.14
                    MascotView(
                        size: starSize,
                        speechText: mascotSpeech,
                        showSpeech: showMascotSpeech,
                        tailDirection: .right,
                        bounce: mascotBounce
                    )
                    .position(
                        x: geo.size.width - starSize * 0.45,
                        y: geo.size.height - starSize * 0.20
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                }

                if let d = drag {
                    Dragging3DTile(letter: d.letter, color: d.color, size: d.tileSize * 1.3)
                        .shadow(color: d.color.opacity(0.45), radius: 16, x: 0, y: 8)
                        .position(d.position)
                        .allowsHitTesting(false)
                        .zIndex(99)
                }

                if let origin = sparkleOrigin {
                    SparkleParticleView(origin: origin)
                        .allowsHitTesting(false)
                        .zIndex(98)
                }

                if showAllDone {
                    FillAllDoneView(completedCount: completedCount, geo: geo) {
                        dismiss()
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onChange(of: puzzleState) { _, state in
            if state == .wrong {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    puzzleState = .idle
                }
            }
        }
        .onChange(of: currentIndex) { _, _ in
            showReward = false
            isRevealed = false
            puzzleState = .idle
            wrongCount = 0
            mascotSpeech = nil
            showMascotSpeech = false
            sparkleOrigin = nil
            bankLetters = Self.makeBankLetters(for: puzzle)
        }
        .onAppear {
            let total = WordPuzzle.all.count
            if savedCount >= total {
                completedCount = 0
                currentIndex = 0
                savedCount = 0
            } else {
                completedCount = savedCount
                currentIndex = savedCount
            }
            bankLetters = Self.makeBankLetters(for: puzzle)
            #if os(iOS)
            ModelCache.shared.preload(puzzle.modelName)
            #endif
        }
    }

    // MARK: - Top bar

    private func topBar(geo: GeometryProxy) -> some View {
        let minDim = min(geo.size.width, geo.size.height)
        return HStack {
            BackButton { dismiss() }
            Spacer()
            Text("FILL")
                .font(.app(size: min(minDim * 0.04, 26)))
                .foregroundStyle(Color.appOrange)
            Spacer()
            HStack(spacing: minDim * 0.008) {
                ForEach(0..<WordPuzzle.all.count, id: \.self) { i in
                    Circle()
                        .fill(
                            i < completedCount
                            ? Color(red: 0.18, green: 0.65, blue: 0.35)
                            : i == currentIndex
                            ? Color.appOrange
                            : Color.appCardBorder
                        )
                        .frame(width: i == currentIndex ? minDim * 0.016 : minDim * 0.010,
                               height: i == currentIndex ? minDim * 0.016 : minDim * 0.010)
                        .animation(.spring(response: 0.28), value: currentIndex)
                }
            }
        }
        .padding(.horizontal, geo.size.width * 0.03)
        .padding(.top, geo.size.height * 0.02)
        .padding(.bottom, geo.size.height * 0.01)
    }

    // MARK: - Word tiles row

    @ViewBuilder
    private func wordRow(geo: GeometryProxy) -> some View {
        let minDim = min(geo.size.width, geo.size.height)
        let tileSize = min(minDim * 0.16, 100)
        HStack(spacing: minDim * 0.02) {
            ForEach(puzzle.letters) { letter in
                if letter.isBlank {
                    BlankTile(
                        tileSize: tileSize,
                        isHighlighted: slotHighlighted,
                        puzzleState: puzzleState,
                        revealedLetter: isRevealed ? puzzle.missingLetter : nil,
                        revealedColor:  letterColor(puzzle.missingLetter)
                    )
                    .overlay(
                        GeometryReader { g in
                            Color.clear
                                .onAppear {
                                    DispatchQueue.main.async {
                                        slotFrame = g.frame(in: .global)
                                    }
                                }
                                .onChange(of: tileSize) { _, _ in
                                    DispatchQueue.main.async {
                                        slotFrame = g.frame(in: .global)
                                    }
                                }
                                .onChange(of: geo.size) { _, _ in
                                    DispatchQueue.main.async {
                                        slotFrame = g.frame(in: .global)
                                    }
                                }
                        }
                    )
                } else {
                    FlatTile(
                        letter: letter.character,
                        color: letterColor(letter.character),
                        size: tileSize
                    )
                }
            }
        }
    }

    // MARK: - Letter bank

    @ViewBuilder
    private func letterBank(geo: GeometryProxy) -> some View {
        let minDim = min(geo.size.width, geo.size.height)
        let isLand = geo.size.width > geo.size.height
        let tileSize = min(minDim * 0.12, 80)
        let spacing = isLand ? geo.size.width * 0.012 : minDim * 0.015
        HStack(spacing: spacing) {
            ForEach(bankLetters, id: \.self) { letter in
                FlatTile(
                    letter: letter,
                    color: letterColor(letter),
                    size: tileSize,
                    dimmed: isRevealed || drag?.letter == letter
                )
                .overlay(
                    Group {
                        if wrongCount >= 3 && letter == puzzle.missingLetter && !isRevealed {
                            HintGlowOverlay(size: tileSize)
                        }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            if drag == nil {
                                SoundPlayer.shared.play(.tap)
                                speaker.speakLetter(letter)
                                if !mascotVisible {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                        mascotVisible = true
                                    }
                                }
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                            drag = DragState(
                                letter: letter,
                                color: letterColor(letter),
                                position: value.location,
                                tileSize: tileSize
                            )
                            let over = slotFrame.insetBy(dx: -20, dy: -20)
                                .contains(value.location)
                            if over != slotHighlighted { slotHighlighted = over }
                        }
                        .onEnded { value in
                            let hit = slotFrame.insetBy(dx: -20, dy: -20)
                                .contains(value.location)
                            let saved = drag
                            drag = nil
                            slotHighlighted = false
                            if hit, let d = saved {
                                handleDrop(d.letter)
                            }
                        }
                )
                .disabled(isRevealed)
            }
        }
    }

    // MARK: - Logic

    private func handleDrop(_ letter: Character) {
        guard puzzleState == .idle else { return }
        if letter == puzzle.missingLetter {
            SoundPlayer.shared.play(.pop)
            puzzleState = .correct
            earnedStars = AchievementStore.fillStars(wrongCount: wrongCount)
            AchievementStore.shared.setStars(activity: puzzle.modelName, type: "fill", stars: earnedStars)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                isRevealed = true
            }
            bounceMascot(height: -25)
            showMascotMessage("Yes! That's right!")
            speaker.speak("Yes! That's right!")
            sparkleOrigin = CGPoint(x: slotFrame.midX, y: slotFrame.midY)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { sparkleOrigin = nil }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
            // Wait for "Yes! That's right!" to finish before spelling
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                SoundPlayer.shared.play(.success)
                speaker.spellThenSpeak(puzzle.word)
            }
            // Show reward after spelling completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                SoundPlayer.shared.play(.whoosh)
                withAnimation(.easeInOut(duration: 0.45)) {
                    showReward = true
                }
            }
        } else {
            SoundPlayer.shared.play(.wrong)
            puzzleState = .wrong
            wrongCount += 1
            bounceMascot(height: -8)
            if wrongCount >= 3 {
                let hintMsg = "Look for the \(String(puzzle.missingLetter))!"
                showMascotMessage(hintMsg)
                speaker.speak(hintMsg)
            } else {
                showMascotMessage("Try again!")
                speaker.speak("Try again!")
            }
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }

    private func bounceMascot(height: CGFloat) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.3)) {
            mascotBounce = height
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                mascotBounce = 0
            }
        }
    }

    private func showMascotMessage(_ text: String) {
        mascotSpeech = text
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            showMascotSpeech = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showMascotSpeech = false
            }
        }
    }

    private func advanceWord() {
        completedCount += 1
        savedCount = completedCount
        if isLastWord {
            withAnimation(.easeInOut(duration: 0.45)) { showAllDone = true }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { showReward = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isRevealed = false
                puzzleState = .idle
                currentIndex += 1
            }
        }
    }

    // MARK: - Colour map

    private func letterColor(_ v: Character) -> Color {
        switch v {
        case "A": return Color(red: 0.90, green: 0.30, blue: 0.30)
        case "B": return Color(red: 0.20, green: 0.55, blue: 0.85)
        case "C": return Color(red: 0.95, green: 0.55, blue: 0.10)
        case "D": return Color(red: 0.55, green: 0.35, blue: 0.75)
        case "E": return Color(red: 0.18, green: 0.65, blue: 0.40)
        case "G": return Color(red: 0.85, green: 0.45, blue: 0.65)
        case "H": return Color(red: 0.30, green: 0.70, blue: 0.70)
        case "I": return Color(red: 0.80, green: 0.60, blue: 0.20)
        case "K": return Color(red: 0.60, green: 0.40, blue: 0.30)
        case "N": return Color(red: 0.45, green: 0.55, blue: 0.80)
        case "O": return Color(red: 0.85, green: 0.40, blue: 0.20)
        case "P": return Color(red: 0.65, green: 0.30, blue: 0.60)
        case "R": return Color(red: 0.75, green: 0.25, blue: 0.25)
        case "S": return Color(red: 0.25, green: 0.60, blue: 0.55)
        case "T": return Color(red: 0.50, green: 0.40, blue: 0.70)
        case "U": return Color(red: 0.70, green: 0.50, blue: 0.15)
        case "Y": return Color(red: 0.85, green: 0.70, blue: 0.10)
        default:  return Color(red: 0.40, green: 0.35, blue: 0.30)
        }
    }
}

// MARK: - Hint glow overlay

private struct HintGlowOverlay: View {
    let size: CGFloat
    @State private var glowing = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .fill(Color(red: 1.0, green: 0.82, blue: 0.0).opacity(glowing ? 0.55 : 0.20))
            .blur(radius: 8)
            .scaleEffect(glowing ? 1.12 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: glowing)
            .onAppear { glowing = true }
            .allowsHitTesting(false)
    }
}

// MARK: - Flat tile

private struct FlatTile: View {
    let letter: Character
    let color:  Color
    let size:   CGFloat
    var dimmed: Bool = false

    var body: some View {
        ZStack {
            Image("box")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()

            Text(String(letter))
                .font(.app(size: size * 0.48))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .opacity(dimmed ? 0.35 : 1.0)
    }
}

// MARK: - Blank drop target tile

private struct BlankTile: View {
    let tileSize:      CGFloat
    let isHighlighted: Bool
    let puzzleState:   PuzzleState
    var revealedLetter: Character? = nil
    var revealedColor:  Color = .primary

    @State private var shakeOffset: CGFloat = 0
    @State private var popScale: CGFloat = 1.0

    private let glowColor = Color(red: 1.0, green: 0.75, blue: 0.0)
    private var isRevealed: Bool { revealedLetter != nil }

    var body: some View {
        ZStack {
            if isHighlighted && !isRevealed {
                RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                    .fill(glowColor.opacity(0.35))
                    .blur(radius: 10)
                    .scaleEffect(1.18)
            }

            Image("box")
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipped()
                .opacity(isRevealed ? 1.0 : 0.5)
                .overlay(
                    RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                        .strokeBorder(
                            isRevealed
                            ? Color.clear
                            : isHighlighted ? glowColor : Color.appCardBorder.opacity(0.6),
                            style: StrokeStyle(
                                lineWidth: isHighlighted ? 3 : 2,
                                dash: isHighlighted ? [] : [8, 5]
                            )
                        )
                )
                .scaleEffect(isHighlighted && !isRevealed ? 1.08 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHighlighted)

            if let letter = revealedLetter {
                Text(String(letter))
                    .font(.app(size: tileSize * 0.48))
                    .foregroundStyle(revealedColor)
                    .scaleEffect(popScale)
                    .onAppear {
                        popScale = 0.4
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                            popScale = 1.0
                        }
                    }
            } else {
                Text("?")
                    .font(.app(size: tileSize * 0.38))
                    .foregroundStyle(
                        isHighlighted
                        ? glowColor
                        : Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.45)
                    )
            }
        }
        .frame(width: tileSize, height: tileSize)
        .offset(x: shakeOffset)
        .onChange(of: puzzleState) { _, state in
            if state == .wrong { shake() }
        }
    }

    private func shake() {
        let s = Animation.spring(response: 0.07, dampingFraction: 0.18)
        withAnimation(s) { shakeOffset = 12 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(s) { shakeOffset = -10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                withAnimation(s) { shakeOffset = 6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    withAnimation(s) { shakeOffset = 0 }
                }
            }
        }
    }
}

// MARK: - Floating drag tile

private struct Dragging3DTile: View {
    let letter: Character
    let color:  Color
    let size:   CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color.white)
                .frame(width: size, height: size)

            Text(String(letter))
                .font(.app(size: size * 0.48))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-4))
    }
}

// MARK: - Fill Reward view

private struct FillRewardView: View {
    let word: String
    let imageName: String
    let modelName: String
    let stars: Int
    let geo: GeometryProxy
    let isLastWord: Bool
    let onContinue: () -> Void

    @State private var modelVisible = false
    @State private var labelVisible = false

    private var hasModel: Bool {
        Bundle.main.url(forResource: modelName, withExtension: "usdz") != nil
    }

    var body: some View {
        let minDim = min(geo.size.width, geo.size.height)
        let isLand = geo.size.width > geo.size.height
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .ignoresSafeArea(.all)

            VStack(spacing: geo.size.height * 0.025) {
                Spacer()
                #if os(iOS)
                if hasModel {
                    SharedModelView(modelName: modelName)
                        .frame(width: geo.size.width * 0.92,
                               height: isLand ? geo.size.height * 0.55 : geo.size.height * 0.40)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(modelVisible ? 1.0 : 0.4)
                        .opacity(modelVisible ? 1.0 : 0)
                        .animation(.spring(response: 0.65, dampingFraction: 0.58).delay(0.1), value: modelVisible)
                } else {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.80)
                        .scaleEffect(modelVisible ? 1.0 : 0.4)
                        .opacity(modelVisible ? 1.0 : 0)
                        .animation(.spring(response: 0.65, dampingFraction: 0.58).delay(0.1), value: modelVisible)
                }
                #else
                Image(imageName).resizable().scaledToFit()
                    .frame(width: min(geo.size.width * 0.60, 480))
                    .scaleEffect(modelVisible ? 1.0 : 0.4).opacity(modelVisible ? 1.0 : 0)
                    .animation(.spring(response: 0.65, dampingFraction: 0.58).delay(0.1), value: modelVisible)
                #endif

                StarRatingView(stars: stars, size: min(minDim * 0.065, 40))
                    .scaleEffect(labelVisible ? 1.0 : 0.6).opacity(labelVisible ? 1.0 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: labelVisible)

                Text(word)
                    .font(.app(size: min(minDim * 0.10, 60)))
                    .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
                    .scaleEffect(labelVisible ? 1.0 : 0.6).opacity(labelVisible ? 1.0 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: labelVisible)

                Spacer()

                Button(action: onContinue) {
                    HStack(spacing: minDim * 0.015) {
                        Text(isLastWord ? "ALL DONE!" : "NEXT WORD")
                            .font(.app(size: min(minDim * 0.035, 22)))
                        if !isLastWord {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: min(minDim * 0.035, 22), weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, geo.size.width * 0.05)
                    .padding(.vertical, geo.size.height * 0.018)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.62, blue: 0.32)))
                }
                .buttonStyle(.plain)
                .scaleEffect(labelVisible ? 1.0 : 0.6).opacity(labelVisible ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.7), value: labelVisible)
                .padding(.bottom, geo.size.height * 0.06)
            }
            .frame(width: geo.size.width, height: geo.size.height)

            ConfettiView()
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
        }
        .onAppear {
            SoundPlayer.shared.play(.reward)
            modelVisible = true; labelVisible = true
        }
    }
}

// MARK: - All Done celebration

private struct FillAllDoneView: View {
    let completedCount: Int
    let geo: GeometryProxy
    let onDismiss: () -> Void

    @State private var starScale: CGFloat = 0.3
    @State private var starOpacity: Double = 0
    @State private var labelVisible = false
    @State private var floatY: CGFloat = 0

    var body: some View {
        let minDim = min(geo.size.width, geo.size.height)
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .ignoresSafeArea(.all)

            VStack(spacing: geo.size.height * 0.03) {
                Spacer()
                Image("startmascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(minDim * 0.55, 360))
                    .scaleEffect(starScale)
                    .opacity(starOpacity)
                    .offset(y: floatY)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: floatY)

                VStack(spacing: geo.size.height * 0.012) {
                    Text("AMAZING!")
                        .font(.app(size: min(minDim * 0.10, 58)))
                        .foregroundStyle(Color.appOrange)
                        .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)

                    Text("You filled \(completedCount) word\(completedCount == 1 ? "" : "s")!")
                        .font(.app(size: min(minDim * 0.04, 26)))
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.28))
                }
                .scaleEffect(labelVisible ? 1.0 : 0.6)
                .opacity(labelVisible ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: labelVisible)

                Spacer()

                Button(action: onDismiss) {
                    Text("GO HOME")
                        .font(.app(size: min(minDim * 0.035, 22)))
                        .foregroundStyle(.white)
                        .padding(.horizontal, geo.size.width * 0.07)
                        .padding(.vertical, geo.size.height * 0.018)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.appOrange))
                }
                .buttonStyle(.plain)
                .scaleEffect(labelVisible ? 1.0 : 0.6)
                .opacity(labelVisible ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.8), value: labelVisible)
                .padding(.bottom, geo.size.height * 0.07)
            }

            ConfettiView()
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .onAppear {
            SoundPlayer.shared.play(.reward)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.55).delay(0.1)) {
                starScale = 1.0; starOpacity = 1.0
            }
            labelVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { floatY = -14 }
        }
    }
}
