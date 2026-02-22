import SwiftUI

// MARK: - ConfettiView

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date = .now

    private let colors: [Color] = [
        Color(red: 1.0, green: 0.30, blue: 0.30),
        Color(red: 0.20, green: 0.55, blue: 0.85),
        Color(red: 0.18, green: 0.65, blue: 0.35),
        Color(red: 1.0, green: 0.78, blue: 0.10),
        Color(red: 0.60, green: 0.30, blue: 0.70),
        Color(red: 1.0, green: 0.55, blue: 0.10),
        Color(red: 0.85, green: 0.45, blue: 0.65),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                for p in particles {
                    let age = elapsed - p.delay
                    guard age > 0 && age < p.lifetime else { continue }
                    let t = age / p.lifetime
                    let x = p.startX * size.width + p.driftX * CGFloat(age)
                    let y = p.startY * size.height + p.velocityY * CGFloat(age) + 0.5 * 280 * CGFloat(age * age)
                    let alpha = 1.0 - t
                    let rotation = p.spin * CGFloat(age)
                    let s = p.size * (1.0 - CGFloat(t) * 0.3)

                    ctx.opacity = alpha
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: x, y: y)
                    transform = transform.rotated(by: rotation)

                    switch p.shape {
                    case 0:
                        let rect = CGRect(x: -s/2, y: -s/2, width: s, height: s)
                        let path = Path(ellipseIn: rect)
                        ctx.fill(path.applying(transform), with: .color(p.color))
                    case 1:
                        let rect = CGRect(x: -s/2, y: -s/4, width: s, height: s/2)
                        let path = Path(roundedRect: rect, cornerRadius: 2)
                        ctx.fill(path.applying(transform), with: .color(p.color))
                    default:
                        let star = starPath(center: .zero, size: s)
                        ctx.fill(star.applying(transform), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startTime = .now
            particles = (0..<60).map { _ in
                ConfettiParticle(
                    startX: CGFloat.random(in: 0.05...0.95),
                    startY: CGFloat.random(in: -0.15...0.05),
                    velocityY: CGFloat.random(in: 30...80),
                    driftX: CGFloat.random(in: -30...30),
                    spin: CGFloat.random(in: -6...6),
                    size: CGFloat.random(in: 6...14),
                    color: colors.randomElement()!,
                    shape: Int.random(in: 0...2),
                    delay: Double.random(in: 0...0.5),
                    lifetime: Double.random(in: 2.5...3.5)
                )
            }
        }
    }

    private func starPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let points = 5
        let outerR = size / 2
        let innerR = outerR * 0.4
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - ConfettiParticle

private struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let velocityY: CGFloat
    let driftX: CGFloat
    let spin: CGFloat
    let size: CGFloat
    let color: Color
    let shape: Int
    let delay: Double
    let lifetime: Double
}

// MARK: - SparkleParticleView

struct SparkleParticleView: View {
    let origin: CGPoint
    @State private var particles: [SparkleParticle] = []
    @State private var startTime: Date = .now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                for p in particles {
                    let age = elapsed
                    guard age < p.lifetime else { continue }
                    let t = age / p.lifetime
                    let x = origin.x + p.dirX * CGFloat(age) * 120
                    let y = origin.y + p.dirY * CGFloat(age) * 120
                    let alpha = 1.0 - t
                    let s = p.size * (1.0 - CGFloat(t))
                    guard s > 0 else { continue }
                    ctx.opacity = alpha
                    let star = starPath(center: CGPoint(x: x, y: y), size: s)
                    ctx.fill(star, with: .color(Color(red: 1.0, green: 0.82, blue: 0.0)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startTime = .now
            particles = (0..<12).map { i in
                let angle = CGFloat(i) * (2 * .pi / 12)
                return SparkleParticle(
                    dirX: cos(angle),
                    dirY: sin(angle),
                    size: CGFloat.random(in: 8...16),
                    lifetime: 0.8
                )
            }
        }
    }

    private func starPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let points = 4
        let outerR = size / 2
        let innerR = outerR * 0.35
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - SparkleParticle

private struct SparkleParticle {
    let dirX: CGFloat
    let dirY: CGFloat
    let size: CGFloat
    let lifetime: Double
}
