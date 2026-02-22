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
                // ── Background ────────────────────────────────────────
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)

                if showReward {
                    // ── 3D reward screen ─────────────────────────────────
                    FillRewardView(
                        word: puzzle.word,
                        imageName: puzzle.modelName,
                        modelName: puzzle.modelName,
                        geo: geo,
                        isLastWord: isLastWord
                    ) {
                        advanceWord()
                    }
                    .transition(.opacity)
                    .zIndex(2)
                } else {
                    // ── Main layout ───────────────────────────────────────
                    VStack(spacing: 0) {
                        topBar(geo: geo)

                        Spacer(minLength: geo.size.height * 0.02)

                        // Word illustration — scales with screen height, capped
                        Image(puzzle.modelName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.26, geo.size.width * 0.22))

                        Spacer(minLength: geo.size.height * 0.03)

                        // Word tiles row: C _ T
                        wordRow(geo: geo)

                        Spacer(minLength: geo.size.height * 0.03)

                        // Hint text
                        Text(isRevealed ? "AMAZING!" : "DRAG THE MISSING LETTER!")
                            .font(.app(size: min(geo.size.width * 0.022, 20)))
                            .foregroundStyle(
                                isRevealed
                                ? Color(red: 0.18, green: 0.62, blue: 0.32)
                                : Color(red: 0.55, green: 0.42, blue: 0.28)
                            )
                            .animation(.easeInOut(duration: 0.25), value: isRevealed)
                            .padding(.bottom, geo.size.height * 0.02)

                        // Letter bank
                        letterBank(geo: geo)
                            .padding(.bottom, geo.size.height * 0.02)

                        Spacer(minLength: geo.size.height * 0.02)
                    }
                }

                // ── Floating 3D drag tile ─────────────────────────────
                if let d = drag {
                    Dragging3DTile(letter: d.letter, color: d.color, size: d.tileSize * 1.3)
                        .shadow(color: d.color.opacity(0.45), radius: 16, x: 0, y: 8)
                        .position(d.position)
                        .allowsHitTesting(false)
                        .zIndex(99)
                }

                // ── All done celebration ───────────────────────────────
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
            bankLetters = Self.makeBankLetters(for: puzzle)
        }
        .onAppear {
            let total = WordPuzzle.all.count
            if savedCount >= total {
                // Already finished all — restart from scratch
                completedCount = 0
                currentIndex = 0
                savedCount = 0
            } else {
                completedCount = savedCount
                currentIndex = savedCount
            }
            bankLetters = Self.makeBankLetters(for: puzzle)
        }
    }

    // MARK: - Top bar

    private func topBar(geo: GeometryProxy) -> some View {
        HStack {
            BackButton { dismiss() }
            Spacer()
            Text("FILL")
                .font(.app(size: min(geo.size.width * 0.028, 26)))
                .foregroundStyle(Color.appOrange)
            Spacer()
            // Progress dots
            HStack(spacing: geo.size.width * 0.008) {
                ForEach(0..<WordPuzzle.all.count, id: \.self) { i in
                    Circle()
                        .fill(
                            i < completedCount
                            ? Color(red: 0.18, green: 0.65, blue: 0.35)
                            : i == currentIndex
                            ? Color.appOrange
                            : Color.appCardBorder
                        )
                        .frame(width: i == currentIndex ? geo.size.width * 0.016 : geo.size.width * 0.010,
                               height: i == currentIndex ? geo.size.width * 0.016 : geo.size.width * 0.010)
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
        let tileSize = min(geo.size.width * 0.14, geo.size.height * 0.13)
        HStack(spacing: geo.size.width * 0.018) {
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
        let tileSize = min(geo.size.width * 0.11, geo.size.height * 0.10)
        HStack(spacing: geo.size.width * 0.012) {
            ForEach(bankLetters, id: \.self) { letter in
                FlatTile(
                    letter: letter,
                    color: letterColor(letter),
                    size: tileSize,
                    dimmed: isRevealed || drag?.letter == letter
                )
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            if drag == nil {
                                SoundPlayer.shared.play(.tap)
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

    // nextButton removed — reward view now has the continue button

    // MARK: - Logic

    private func handleDrop(_ letter: Character) {
        guard puzzleState == .idle else { return }
        if letter == puzzle.missingLetter {
            SoundPlayer.shared.play(.pop)
            puzzleState = .correct
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                isRevealed = true
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SoundPlayer.shared.play(.success)
                speaker.spellThenSpeak(puzzle.word)
            }
            // Show 3D reward after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                SoundPlayer.shared.play(.whoosh)
                withAnimation(.easeInOut(duration: 0.45)) {
                    showReward = true
                }
            }
        } else {
            SoundPlayer.shared.play(.wrong)
            puzzleState = .wrong
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
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
        Color(red: 0.28, green: 0.24, blue: 0.20)
    }
}

// MARK: - Flat tile (word row + letter bank)
// Uses box.png as background, letter rendered on top.

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
    var revealedLetter: Character? = nil   // set when correct letter is dropped
    var revealedColor:  Color = .primary

    @State private var shakeOffset: CGFloat = 0
    @State private var popScale: CGFloat = 1.0

    private let glowColor = Color(red: 1.0, green: 0.75, blue: 0.0)
    private var isRevealed: Bool { revealedLetter != nil }

    var body: some View {
        ZStack {
            // Glow halo (only when dragging over, not after reveal)
            if isHighlighted && !isRevealed {
                RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                    .fill(glowColor.opacity(0.35))
                    .blur(radius: 10)
                    .scaleEffect(1.18)
            }

            // Box background
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
                // Revealed letter — full opacity, pops in
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

// MARK: - Floating drag tile (lightweight 2D — no SceneKit overhead)

private struct Dragging3DTile: View {
    let letter: Character
    let color:  Color
    let size:   CGFloat

    var body: some View {
        ZStack {
            // Soft background card
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

// MARK: - Fill Reward view (3D model after correct answer)

private struct FillRewardView: View {
    let word: String
    let imageName: String
    let modelName: String
    let geo: GeometryProxy
    let isLastWord: Bool
    let onContinue: () -> Void

    @State private var modelVisible = false
    @State private var labelVisible = false

    private var hasModel: Bool {
        Bundle.main.url(forResource: modelName, withExtension: "usdz") != nil
    }

    var body: some View {
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
                    FillModelRealityView(modelName: modelName)
                        .frame(width: geo.size.width * 0.92,
                               height: geo.size.height * 0.55)
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

                Text(word)
                    .font(.app(size: min(geo.size.width * 0.07, 60)))
                    .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
                    .scaleEffect(labelVisible ? 1.0 : 0.6).opacity(labelVisible ? 1.0 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: labelVisible)

                Spacer()

                Button(action: onContinue) {
                    HStack(spacing: geo.size.width * 0.015) {
                        Text(isLastWord ? "ALL DONE!" : "NEXT WORD")
                            .font(.app(size: min(geo.size.width * 0.025, 22)))
                        if !isLastWord {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: min(geo.size.width * 0.025, 22), weight: .bold))
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
        }
        .onAppear {
            SoundPlayer.shared.play(.reward)
            modelVisible = true; labelVisible = true
        }
    }
}

// MARK: - RealityKit 3D model for Fill reward

#if os(iOS)
private struct FillModelRealityView: UIViewRepresentable {
    let modelName: String

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)
        arView.environment.lighting.intensityExponent = 1.5

        guard let url = Bundle.main.url(forResource: modelName, withExtension: "usdz"),
              let model = try? Entity.load(contentsOf: url) else { return arView }
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(model); arView.scene.addAnchor(anchor)
        let bounds = model.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        let baseScale = maxDim > 0 ? Float(0.35 / maxDim) : 1.0
        model.scale    = SIMD3<Float>(repeating: baseScale)
        model.position = SIMD3<Float>(-bounds.center.x*baseScale, -bounds.center.y*baseScale, -0.45)

        let coord = context.coordinator
        coord.modelEntity = model
        coord.baseScale = baseScale

        // Gentle idle spin — pauses when kid is touching
        var elapsed: Float = 0
        arView.scene.subscribe(to: SceneEvents.Update.self) { ev in
            guard !coord.isTouching else { return }
            elapsed += Float(ev.deltaTime) * 0.35
            model.transform.rotation = simd_quatf(angle: elapsed, axis: [0, 1, 0])
        }.store(in: &coord.bag)

        let cam = PerspectiveCamera(); cam.camera.fieldOfViewInDegrees = 28
        let camAnchor = AnchorEntity(world: [0, 0, 0.55]); camAnchor.addChild(cam)
        arView.scene.addAnchor(camAnchor)

        // Drag to spin
        let pan = UIPanGestureRecognizer(target: coord, action: #selector(FillCoordinator.handlePan(_:)))
        arView.addGestureRecognizer(pan)

        // Pinch to zoom
        let pinch = UIPinchGestureRecognizer(target: coord, action: #selector(FillCoordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
    func makeCoordinator() -> FillCoordinator { FillCoordinator() }
}

class FillCoordinator: NSObject {
    var bag = Set<AnyCancellable>()
    var modelEntity: Entity?
    var baseScale: Float = 1.0
    var isTouching = false

    private var rotationX: Float = 0
    private var rotationY: Float = 0
    private var currentZoom: Float = 1.0

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let model = modelEntity else { return }
        switch gesture.state {
        case .began:
            isTouching = true
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            rotationY += Float(translation.x) * 0.008
            rotationX += Float(translation.y) * 0.008
            rotationX = min(max(rotationX, -.pi / 3), .pi / 3)
            let qX = simd_quatf(angle: rotationX, axis: [1, 0, 0])
            let qY = simd_quatf(angle: rotationY, axis: [0, 1, 0])
            model.transform.rotation = qY * qX
            gesture.setTranslation(.zero, in: gesture.view)
        case .ended, .cancelled:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isTouching = false
            }
        default: break
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let model = modelEntity else { return }
        switch gesture.state {
        case .began:
            isTouching = true
        case .changed:
            currentZoom = min(max(Float(gesture.scale) * currentZoom, 0.5), 3.0)
            model.scale = SIMD3<Float>(repeating: baseScale * currentZoom)
            gesture.scale = 1.0
        case .ended, .cancelled:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isTouching = false
            }
        default: break
        }
    }
}
#endif

// MARK: - All Done celebration screen (Fill)

private struct FillAllDoneView: View {
    let completedCount: Int
    let geo: GeometryProxy
    let onDismiss: () -> Void

    @State private var starScale: CGFloat = 0.3
    @State private var starOpacity: Double = 0
    @State private var labelVisible = false
    @State private var floatY: CGFloat = 0

    var body: some View {
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
                    .frame(width: min(geo.size.width * 0.50, 360))
                    .scaleEffect(starScale)
                    .opacity(starOpacity)
                    .offset(y: floatY)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: floatY)

                VStack(spacing: geo.size.height * 0.012) {
                    Text("AMAZING!")
                        .font(.app(size: min(geo.size.width * 0.07, 58)))
                        .foregroundStyle(Color.appOrange)
                        .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)

                    Text("You filled \(completedCount) word\(completedCount == 1 ? "" : "s")!")
                        .font(.app(size: min(geo.size.width * 0.032, 26)))
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.28))
                }
                .scaleEffect(labelVisible ? 1.0 : 0.6)
                .opacity(labelVisible ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: labelVisible)

                Spacer()

                Button(action: onDismiss) {
                    Text("GO HOME")
                        .font(.app(size: min(geo.size.width * 0.025, 22)))
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
