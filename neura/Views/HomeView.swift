import SwiftUI

struct HomeView: View {

    @AppStorage("drawCompletedCount") private var drawCompleted = 0
    @AppStorage("fillCompletedCount") private var fillCompleted = 0

    @State private var navigateTo: HomeDestination? = nil
    @State private var cardsVisible  = false
    @State private var mascotVisible = false
    @State private var bubbleVisible = false
    @State private var bubbleText = ""
    @State private var hasAppeared   = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {

                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea(.all)

                    let isLand = geo.size.width > geo.size.height
                    VStack(spacing: 0) {
                        Text("neura")
                            .font(.app(size: min(min(geo.size.width, geo.size.height) * 0.10, 56)))
                            .foregroundStyle(Color.appOrange)
                            .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)
                            .padding(.top, geo.size.height * (isLand ? 0.07 : 0.05))

                        Spacer()

                        cardsLayout(geo: geo, isLand: isLand)
                            .frame(maxWidth: .infinity)

                        Spacer(minLength: geo.size.height * (isLand ? 0.16 : 0.10))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)

                    let minDim = min(geo.size.width, geo.size.height)
                    let starSize: CGFloat = min(minDim * 0.20, 160)
                    let starCX: CGFloat = starSize * 0.45
                    let starCY: CGFloat = geo.size.height - starSize * 0.10

                    if mascotVisible {
                        Image("startmascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: starSize)
                            .position(x: starCX, y: starCY)
                            .transition(.move(edge: .bottom).combined(with: .opacity))

                        if bubbleVisible {
                            SpeechBubble(text: bubbleText, geo: geo)
                                .position(
                                    x: starCX + geo.size.width * 0.12,
                                    y: starCY - starSize * 0.90
                                )
                                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea(.all)
            .navigationBarHidden(true)
            .onAppear {
                cardsVisible = true
                let greeting = homeGreeting()
                if hasAppeared {
                    mascotVisible = true
                    bubbleText    = greeting
                    bubbleVisible = true
                } else {
                    hasAppeared = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                            mascotVisible = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            bubbleText = greeting
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                bubbleVisible = true
                            }
                        }
                    }
                }
            }
            .navigationDestination(item: $navigateTo) { dest in
                switch dest {
                case .draw: LetsDrawView()
                case .fill: LearnWordsView()
                }
            }
        }
    }

    @ViewBuilder
    private func cardsLayout(geo: GeometryProxy, isLand: Bool) -> some View {
        if isLand {
            HStack(spacing: geo.size.width * 0.06) {
                Spacer(minLength: 0)
                activityCardView(title: "DRAW", imageName: "drawasset",
                                 progress: drawCompleted, total: DrawActivity.all.count,
                                 mascotText: "Let's draw! Pick up your brush!",
                                 destination: .draw, delay: 0.05, geo: geo)
                activityCardView(title: "FILL", imageName: "fillwords",
                                 progress: fillCompleted, total: WordPuzzle.all.count,
                                 mascotText: "Let's fill in the letters! You can do it!",
                                 destination: .fill, delay: 0.18, geo: geo)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: geo.size.height * 0.025) {
                activityCardView(title: "DRAW", imageName: "drawasset",
                                 progress: drawCompleted, total: DrawActivity.all.count,
                                 mascotText: "Let's draw! Pick up your brush!",
                                 destination: .draw, delay: 0.05, geo: geo)
                activityCardView(title: "FILL", imageName: "fillwords",
                                 progress: fillCompleted, total: WordPuzzle.all.count,
                                 mascotText: "Let's fill in the letters! You can do it!",
                                 destination: .fill, delay: 0.18, geo: geo)
            }
        }
    }

    private func activityCardView(title: String, imageName: String,
                                   progress: Int, total: Int,
                                   mascotText: String, destination: HomeDestination,
                                   delay: Double, geo: GeometryProxy) -> some View {
        ActivityCard(title: title, imageName: imageName,
                     progress: progress, total: total, geo: geo) {
            showMascot(text: mascotText, geo: geo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                navigateTo = destination
            }
        }
        .frame(width: cardWidth(geo), height: cardHeight(geo))
        .scaleEffect(cardsVisible ? 1.0 : 0.75)
        .opacity(cardsVisible ? 1.0 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(delay), value: cardsVisible)
    }

    private func cardWidth(_ geo: GeometryProxy) -> CGFloat {
        let isLand = geo.size.width > geo.size.height
        return isLand
            ? min(geo.size.width * 0.36, 300)
            : min(geo.size.width * 0.55, 280)
    }
    private func cardHeight(_ geo: GeometryProxy) -> CGFloat {
        let isLand = geo.size.width > geo.size.height
        return isLand
            ? cardWidth(geo) * 1.30
            : cardWidth(geo) * 0.85
    }

    private func showMascot(text: String, geo: GeometryProxy) {
        bubbleText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbleVisible = true
        }
    }

    private func homeGreeting() -> String {
        let drawTotal = DrawActivity.all.count
        let fillTotal = WordPuzzle.all.count
        let allDone = drawCompleted >= drawTotal && fillCompleted >= fillTotal
        if allDone {
            return "You finished everything! Play again?"
        } else if drawCompleted > 0 || fillCompleted > 0 {
            return "Welcome back! Keep going!"
        } else {
            return "Hi! Pick an activity!"
        }
    }
}

// MARK: - Speech bubble

private struct SpeechBubble: View {
    let text: String
    let geo: GeometryProxy

    private var minDim: CGFloat { min(geo.size.width, geo.size.height) }
    private var fontSize: CGFloat { min(minDim * 0.028, 20) }
    private var maxWidth: CGFloat { min(minDim * 0.42, 260) }
    private var padding: CGFloat  { minDim * 0.022 }
    private var radius: CGFloat   { minDim * 0.028 }
    private var tailW:  CGFloat   { minDim * 0.030 }
    private var tailH:  CGFloat   { minDim * 0.028 }

    var body: some View {
        Text(text)
            .font(.app(size: fontSize))
            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
            .multilineTextAlignment(.center)
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
            .frame(maxWidth: maxWidth, alignment: .center)
            .background(
                GeometryReader { inner in
                    let fullH = inner.size.height + tailH
                    BottomTailBubble(radius: radius, tailWidth: tailW, tailHeight: tailH)
                        .fill(Color.white.opacity(0.92))
                        .frame(width: inner.size.width, height: fullH)
                        .shadow(color: Color.appCardBorder.opacity(0.35), radius: 8, x: 0, y: 4)
                    BottomTailBubble(radius: radius, tailWidth: tailW, tailHeight: tailH)
                        .stroke(Color.appCardBorder, lineWidth: 1.5)
                        .frame(width: inner.size.width, height: fullH)
                }
                .frame(maxWidth: maxWidth)
            )
    }
}

// MARK: - BottomTailBubble shape

private struct BottomTailBubble: Shape {
    let radius:     CGFloat
    let tailWidth:  CGFloat
    let tailHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailHeight)
        let r = min(radius, body.height / 2, body.width / 2)
        let tailMidX = body.minX + body.width * 0.25

        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.minY + r),
                 radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: tailMidX + tailWidth / 2, y: body.maxY))
        p.addLine(to: CGPoint(x: tailMidX, y: rect.maxY))
        p.addLine(to: CGPoint(x: tailMidX - tailWidth / 2, y: body.maxY))
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.minY + r),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Destination

enum HomeDestination: Hashable {
    case draw, fill
}

// MARK: - Activity card

private struct ActivityCard: View {
    let title: String
    let imageName: String
    let progress: Int
    let total: Int
    let geo: GeometryProxy
    let action: () -> Void

    @State private var pressed = false

    private var cornerRadius: CGFloat { min(geo.size.width * 0.025, 24) }
    private var titleFontSize: CGFloat { min(geo.size.width * 0.028, 26) }
    private var titlePadding: CGFloat  { geo.size.height * 0.018 }
    private var imagePadding: CGFloat  { geo.size.width * 0.02 }
    private var isAllDone: Bool { progress >= total }

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.app(size: titleFontSize))
                        .foregroundStyle(Color.appOrange)

                    if progress > 0 {
                        Text(isAllDone ? "done" : "\(progress)/\(total)")
                            .font(.app(size: titleFontSize * 0.55))
                            .foregroundStyle(
                                isAllDone
                                ? Color(red: 0.18, green: 0.65, blue: 0.35)
                                : Color(red: 0.55, green: 0.42, blue: 0.28)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(
                                        isAllDone
                                        ? Color(red: 0.18, green: 0.65, blue: 0.35).opacity(0.15)
                                        : Color.appCardBorder.opacity(0.25)
                                    )
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, titlePadding)

                Rectangle()
                    .fill(Color.appCardBorder)
                    .frame(height: 1.5)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(imagePadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isAllDone ? Color(red: 0.18, green: 0.65, blue: 0.35) : Color.appCardBorder,
                        lineWidth: isAllDone ? 2.5 : 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.appCardBorder.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        SoundPlayer.shared.play(.tap)
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    }
                }
                .onEnded { _ in pressed = false }
        )
    }
}
