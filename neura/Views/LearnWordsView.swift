import SwiftUI
import SceneKit
#if os(iOS)
import UIKit
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

    @State private var currentIndex  = 0
    @State private var puzzleState: PuzzleState = .idle
    @State private var isRevealed    = false
    @State private var completedCount = 0
    @State private var showAllDone   = false

    @State private var drag: DragState? = nil
    @State private var slotFrame: CGRect = .zero
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

                    if isRevealed {
                        nextButton(geo: geo)
                            .padding(.bottom, geo.size.height * 0.03)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: geo.size.height * 0.02)
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
            isRevealed = false
            puzzleState = .idle
            bankLetters = Self.makeBankLetters(for: puzzle)
        }
        .onAppear {
            if bankLetters.isEmpty {
                bankLetters = Self.makeBankLetters(for: puzzle)
            }
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
                        isHighlighted: drag != nil &&
                            slotFrame.insetBy(dx: -20, dy: -20)
                                .contains(drag?.position ?? .zero),
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
                        }
                        .onEnded { value in
                            let hit = slotFrame.insetBy(dx: -20, dy: -20)
                                .contains(value.location)
                            let saved = drag
                            drag = nil
                            if hit, let d = saved {
                                handleDrop(d.letter)
                            }
                        }
                )
                .disabled(isRevealed)
            }
        }
    }

    // MARK: - Next button

    private func nextButton(geo: GeometryProxy) -> some View {
        let fontSize = min(geo.size.width * 0.022, 20)
        return Button {
            completedCount += 1
            if isLastWord {
                withAnimation(.easeInOut(duration: 0.45)) { showAllDone = true }
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentIndex += 1
                }
            }
        } label: {
            HStack(spacing: geo.size.width * 0.01) {
                Text(isLastWord ? "ALL DONE!" : "NEXT WORD")
                    .font(.app(size: fontSize))
                if !isLastWord {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: fontSize, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, geo.size.width * 0.04)
            .padding(.vertical, geo.size.height * 0.016)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.18, green: 0.62, blue: 0.32))
                    .shadow(color: Color.green.opacity(0.30), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func handleDrop(_ letter: Character) {
        guard puzzleState == .idle else { return }
        if letter == puzzle.missingLetter {
            puzzleState = .correct
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                isRevealed = true
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                speaker.spellThenSpeak(puzzle.word)
            }
        } else {
            puzzleState = .wrong
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }

    // MARK: - Colour map

    private func letterColor(_ v: Character) -> Color {
        switch v {
        case "A": return Color(red: 0.85, green: 0.33, blue: 0.33)
        case "E": return Color(red: 0.27, green: 0.60, blue: 0.85)
        case "I": return Color(red: 0.55, green: 0.35, blue: 0.85)
        case "O": return Color(red: 0.95, green: 0.55, blue: 0.15)
        case "U": return Color(red: 0.25, green: 0.72, blue: 0.48)
        default:  return Color(red: 0.28, green: 0.24, blue: 0.20)
        }
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

// MARK: - Floating 3D drag tile (SceneKit, no rotation gesture)

private struct Dragging3DTile: View {
    let letter: Character
    let color:  Color
    let size:   CGFloat

    var body: some View {
        SceneKit3DLetter(letter: letter, color: color)
            .frame(width: size, height: size)
    }
}

private struct SceneKit3DLetter: UIViewRepresentable {
    let letter: Character
    let color:  Color

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X

        let scene = SCNScene()
        scnView.scene = scene

        // Letter geometry
        let text = SCNText(string: String(letter), extrusionDepth: 5)
        text.font = UIFont.systemFont(ofSize: 24, weight: .black)
        text.flatness = 0.1
        text.chamferRadius = 0.6

        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor(color)
        mat.specular.contents = UIColor.white
        mat.shininess = 90
        mat.lightingModel = .phong
        text.materials = [mat]

        let textNode = SCNNode(geometry: text)

        // Centre pivot
        let (minV, maxV) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation(
            (maxV.x - minV.x) / 2 + minV.x,
            (maxV.y - minV.y) / 2 + minV.y,
            0
        )

        scene.rootNode.addChildNode(textNode)

        // Lighting
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color = UIColor.white.withAlphaComponent(0.5)
        let ambientNode = SCNNode(); ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight(); key.type = .directional
        key.color = UIColor.white
        let keyNode = SCNNode(); keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        // Orthographic camera sized to letter
        let w = maxV.x - minV.x
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(w / 2) * 1.4
        camera.zNear = 0.1; camera.zFar = 200
        let camNode = SCNNode(); camNode.camera = camera
        camNode.position = SCNVector3(0, 0, 60)
        scene.rootNode.addChildNode(camNode)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
    func makeCoordinator() -> () { () }
}

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
            withAnimation(.spring(response: 0.65, dampingFraction: 0.55).delay(0.1)) {
                starScale = 1.0; starOpacity = 1.0
            }
            labelVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { floatY = -14 }
        }
    }
}
