import SwiftUI

struct SplashView: View {

    var onFinished: () -> Void

    @StateObject private var speaker = WordSpeaker()

    @State private var floatY:      CGFloat = 0
    @State private var starScale:   CGFloat = 0.6
    @State private var starOpacity: Double  = 0

    @State private var titleY:      CGFloat = 0
    @State private var titleOpacity: Double = 0

    @State private var tapPulse: CGFloat = 1.0
    @State private var sparkles: [SparkleData] = SparkleData.generate()
    @State private var showGreeting = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                ForEach(sparkles) { sp in
                    SparkleView(data: sp, geo: geo)
                }

                let isLand = geo.size.width > geo.size.height
                let starFrac: CGFloat = isLand ? 0.52 : 0.38
                let mascotW = min(geo.size.width * starFrac, 380)
                ZStack {
                    Image("startmascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: mascotW)
                        .scaleEffect(starScale)
                        .opacity(starOpacity)
                        .shadow(color: Color(red: 1.0, green: 0.90, blue: 0.40).opacity(0.45),
                                radius: 40, x: 0, y: 10)

                    if showGreeting {
                        MascotSpeechBubble(
                            text: "Welcome to Neura!",
                            fontSize: min(min(geo.size.width, geo.size.height) * 0.032, 22),
                            maxWidth: 200
                        )
                        .offset(x: mascotW * 0.38, y: -mascotW * 0.42)
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width / 2,
                          y: geo.size.height * (isLand ? 0.38 : 0.32) + floatY)

                VStack(spacing: 12) {
                    Text("NEURA")
                        .font(.app(size: min(min(geo.size.width, geo.size.height) * 0.13, 96)))
                        .foregroundStyle(Color.appOrange)
                        .shadow(color: Color.appOrange.opacity(0.30),
                                radius: 8, x: 0, y: 4)

                    Text("TAP TO BEGIN!")
                        .font(.app(size: min(min(geo.size.width, geo.size.height) * 0.038, 28)))
                        .foregroundStyle(Color.appOrange.opacity(0.80))
                        .scaleEffect(tapPulse)
                }
                .opacity(titleOpacity)
                .position(x: geo.size.width / 2,
                          y: geo.size.height * (isLand ? 0.80 : 0.72))
                .accessibilityLabel("Tap to begin playing Neura")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard titleOpacity > 0.5 else { return }
                SoundPlayer.shared.play(.pop)
                withAnimation(.easeIn(duration: 0.35)) {
                    starOpacity  = 0
                    titleOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                    onFinished()
                }
            }
            .onAppear { startAnimations() }
        }
        .ignoresSafeArea()
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.2)) {
            starScale   = 1.0
            starOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.5)) {
            floatY = -18
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
            titleOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(1.3)) {
            tapPulse = 1.08
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showGreeting = true
            }
            speaker.speak("Welcome to Neura!")
        }
    }
}

// MARK: - Sparkle data

private struct SparkleData: Identifiable {
    let id    = UUID()
    let x:     CGFloat
    let y:     CGFloat
    let size:  CGFloat
    let delay: Double
    let color: Color

    static func generate() -> [SparkleData] {
        let colors: [Color] = [
            Color(red: 1.0,  green: 0.88, blue: 0.30),
            Color(red: 0.70, green: 0.88, blue: 1.0),
            Color(red: 1.0,  green: 0.70, blue: 0.80),
            Color(red: 0.75, green: 1.0,  blue: 0.75),
        ]
        return (0..<18).map { i in
            SparkleData(
                x:     CGFloat.random(in: 0.05...0.95),
                y:     CGFloat.random(in: 0.04...0.88),
                size:  CGFloat.random(in: 8...22),
                delay: Double(i) * 0.28,
                color: colors[i % colors.count]
            )
        }
    }
}

// MARK: - Sparkle view

private struct SparkleView: View {
    let data: SparkleData
    let geo:  GeometryProxy

    @State private var opacity: Double  = 0
    @State private var scale:   CGFloat = 0.4
    @State private var spin:    Double  = 0

    var body: some View {
        Text("✦")
            .font(.system(size: data.size, weight: .black))
            .foregroundStyle(data.color)
            .opacity(opacity)
            .scaleEffect(scale)
            .rotationEffect(.degrees(spin))
            .position(x: data.x * geo.size.width,
                      y: data.y * geo.size.height)
            .onAppear { animate() }
    }

    private func animate() {
        let dur = Double.random(in: 1.4...2.2)
        withAnimation(
            .easeInOut(duration: dur)
            .repeatForever(autoreverses: true)
            .delay(data.delay)
        ) {
            opacity = Double.random(in: 0.55...1.0)
            scale   = CGFloat.random(in: 0.8...1.4)
            spin    = Double.random(in: 30...90)
        }
    }
}
