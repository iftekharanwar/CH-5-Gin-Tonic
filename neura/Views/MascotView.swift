import SwiftUI

// MARK: - MascotView

struct MascotView: View {
    let size: CGFloat
    var speechText: String? = nil
    var showSpeech: Bool = false
    var tailDirection: TailDirection = .left
    var bounce: CGFloat = 0

    enum TailDirection {
        case left, right
    }

    @State private var floatY: CGFloat = 0
    @State private var isFloating = false

    var body: some View {
        ZStack(alignment: tailDirection == .left ? .topTrailing : .topLeading) {
            Image("startmascot")
                .resizable()
                .scaledToFit()
                .frame(width: size)
                .offset(y: bounce + floatY)
                .accessibilityHidden(true)

            if showSpeech, let text = speechText, !text.isEmpty {
                MascotSpeechBubble(text: text, fontSize: max(size * 0.11, 13), tailDirection: tailDirection)
                    .offset(
                        x: tailDirection == .left ? size * 0.35 : -size * 0.35,
                        y: -size * 0.35
                    )
                    .transition(.scale(scale: 0.6, anchor: tailDirection == .left ? .bottomLeading : .bottomTrailing).combined(with: .opacity))
                    .accessibilityLabel(text)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatY = -6
            }
        }
    }
}

// MARK: - MascotSpeechBubble

struct MascotSpeechBubble: View {
    let text: String
    var fontSize: CGFloat = 16
    var tailDirection: MascotView.TailDirection = .left
    var maxWidth: CGFloat = 220

    var body: some View {
        Text(text)
            .font(.app(size: fontSize))
            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.20))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: maxWidth, alignment: .center)
            .background(
                GeometryReader { inner in
                    let tailH: CGFloat = 10
                    let fullH = inner.size.height + tailH
                    BottomTailBubble(
                        radius: 14,
                        tailWidth: 14,
                        tailHeight: tailH,
                        tailPosition: tailDirection == .left ? 0.25 : 0.75
                    )
                    .fill(Color.white.opacity(0.92))
                    .frame(width: inner.size.width, height: fullH)
                    .shadow(color: Color.appCardBorder.opacity(0.35), radius: 8, x: 0, y: 4)

                    BottomTailBubble(
                        radius: 14,
                        tailWidth: 14,
                        tailHeight: tailH,
                        tailPosition: tailDirection == .left ? 0.25 : 0.75
                    )
                    .stroke(Color.appCardBorder, lineWidth: 1.5)
                    .frame(width: inner.size.width, height: fullH)
                }
            )
    }
}

// MARK: - BottomTailBubble shape

struct BottomTailBubble: Shape {
    let radius:       CGFloat
    let tailWidth:    CGFloat
    let tailHeight:   CGFloat
    var tailPosition: CGFloat = 0.25

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tailHeight)
        let r = min(radius, body.height / 2, body.width / 2)
        let tailMidX = body.minX + body.width * tailPosition

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
