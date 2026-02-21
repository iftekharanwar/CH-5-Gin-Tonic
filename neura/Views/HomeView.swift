import SwiftUI

// MARK: - Home Screen

struct HomeView: View {

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

                    // ── Background — edge to edge ──────────────────────
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea(.all)

                    // ── Main content ───────────────────────────────────
                    VStack(spacing: 0) {
                        // Wordmark
                        Text("neura")
                            .font(.app(size: min(geo.size.width * 0.07, 56)))
                            .foregroundStyle(Color.appOrange)
                            .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)
                            .padding(.top, geo.size.height * 0.07)

                        Spacer()

                        // Cards row
                        HStack(spacing: geo.size.width * 0.06) {
                            Spacer(minLength: 0)
                            ActivityCard(
                                title: "DRAW",
                                imageName: "drawasset",
                                geo: geo
                            ) {
                                showMascot(text: "Let's draw! Pick up your brush!", geo: geo)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    navigateTo = .draw
                                }
                            }
                            .frame(width: cardWidth(geo), height: cardHeight(geo))
                            .scaleEffect(cardsVisible ? 1.0 : 0.75)
                            .opacity(cardsVisible ? 1.0 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.05), value: cardsVisible)

                            ActivityCard(
                                title: "FILL",
                                imageName: "fillwords",
                                geo: geo
                            ) {
                                showMascot(text: "Let's fill in the letters! You can do it!", geo: geo)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    navigateTo = .fill
                                }
                            }
                            .frame(width: cardWidth(geo), height: cardHeight(geo))
                            .scaleEffect(cardsVisible ? 1.0 : 0.75)
                            .opacity(cardsVisible ? 1.0 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.18), value: cardsVisible)

                            Spacer(minLength: 0)
                        }

                        // Space below cards — leave room for mascot
                        Spacer(minLength: geo.size.height * 0.16)
                    }

                    // ── Star peeking from bottom-left + bubble above it ──
                    // Star is large; positioned so only top ~40% is visible above screen bottom
                    let starSize: CGFloat = min(geo.size.width * 0.20, 160)
                    // Star centre X: slightly into screen so face is visible
                    let starCX: CGFloat = starSize * 0.45
                    // Star centre Y: push it down so only top portion peeks above bottom edge
                    let starCY: CGFloat = geo.size.height - starSize * 0.10

                    if mascotVisible {
                        Image("startmascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: starSize)
                            .position(x: starCX, y: starCY)
                            .transition(.move(edge: .bottom).combined(with: .opacity))

                        if bubbleVisible {
                            // Bubble sits just above the visible star tip, shifted left to align with it
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
                if hasAppeared {
                    // Returning from a sub-screen — restore state instantly, no delays
                    mascotVisible = true
                    bubbleText    = "Hi! Pick an activity!"
                    bubbleVisible = true
                } else {
                    hasAppeared = true
                    // First launch — animate everything in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                            mascotVisible = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            bubbleText = "Hi! Pick an activity!"
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

    private func cardWidth(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width * 0.36, 300)
    }
    private func cardHeight(_ geo: GeometryProxy) -> CGFloat {
        cardWidth(geo) * 1.30
    }

    private func showMascot(text: String, geo: GeometryProxy) {
        bubbleText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbleVisible = true
        }
    }
}

// MARK: - Speech bubble (tail points down toward star tip)

private struct SpeechBubble: View {
    let text: String
    let geo: GeometryProxy

    private var fontSize: CGFloat { min(geo.size.width * 0.022, 20) }
    private var maxWidth: CGFloat { min(geo.size.width * 0.34, 260) }
    private var padding: CGFloat  { geo.size.width * 0.022 }
    private var radius: CGFloat   { geo.size.width * 0.028 }
    private var tailW:  CGFloat   { geo.size.width * 0.030 }
    private var tailH:  CGFloat   { geo.size.width * 0.028 }

    var body: some View {
        // Tail is part of the shape frame — pad bottom so text stays inside body only
        Text(text)
            .font(.app(size: fontSize))
            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
            .multilineTextAlignment(.center)
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
            .frame(maxWidth: maxWidth, alignment: .center)
            .background(
                // Shape frame = text frame + tail height below
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

// MARK: - Bubble with bottom-centre tail pointing down

private struct BottomTailBubble: Shape {
    let radius:     CGFloat
    let tailWidth:  CGFloat
    let tailHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        // Body sits in the top portion; tail hangs below
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailHeight)
        let r = min(radius, body.height / 2, body.width / 2)
        // Tail centred on left quarter of bubble (toward the star)
        let tailMidX = body.minX + body.width * 0.25

        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        // Top edge → top-right
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.minY + r),
                 radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        // Right edge → bottom-right
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        // Bottom edge — right of tail
        p.addLine(to: CGPoint(x: tailMidX + tailWidth / 2, y: body.maxY))
        // Tail point
        p.addLine(to: CGPoint(x: tailMidX, y: rect.maxY))
        // Bottom edge — left of tail
        p.addLine(to: CGPoint(x: tailMidX - tailWidth / 2, y: body.maxY))
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        // Left edge → top-left
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
    let geo: GeometryProxy
    let action: () -> Void

    @State private var pressed = false

    private var cornerRadius: CGFloat { min(geo.size.width * 0.025, 24) }
    private var titleFontSize: CGFloat { min(geo.size.width * 0.028, 26) }
    private var titlePadding: CGFloat  { geo.size.height * 0.018 }
    private var imagePadding: CGFloat  { geo.size.width * 0.02 }

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 0) {
                // ── Title area ─────────────────────────────────────────
                Text(title)
                    .font(.app(size: titleFontSize))
                    .foregroundStyle(Color.appOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, titlePadding)

                // ── Divider ────────────────────────────────────────────
                Rectangle()
                    .fill(Color.appCardBorder)
                    .frame(height: 1.5)

                // ── Illustration ───────────────────────────────────────
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
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
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
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    }
                }
                .onEnded { _ in pressed = false }
        )
    }
}
