import SwiftUI
#if os(iOS)
import RealityKit
import Vision
import UIKit
#endif
import Combine

// MARK: - DrawActivity
// Add new assets here — just drop a PNG + USDZ into assets and add one entry.

struct DrawActivity {
    let imageName: String   // asset catalog name (PNG with transparent bg)
    let word: String        // shown on reward screen
    let modelName: String   // USDZ filename (without extension) for reward screen

    init(imageName: String, word: String, modelName: String? = nil) {
        self.imageName = imageName
        self.word = word
        self.modelName = modelName ?? imageName
    }

    static let all: [DrawActivity] = [
        DrawActivity(imageName: "apple", word: "APPLE"),
        DrawActivity(imageName: "bat",   word: "BAT"),
        DrawActivity(imageName: "book",  word: "BOOK"),
        DrawActivity(imageName: "cup",   word: "CUP"),
        DrawActivity(imageName: "dog",   word: "DOG"),
    ]
}

// MARK: - LetsDrawView

struct LetsDrawView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("drawCompletedCount") private var savedCount = 0
    @State private var activityIndex = 0
    @State private var completedCount = 0
    @State private var showAllDone = false

    // Per-round state — reset when moving to next activity
    @State private var strokes: [[CGPoint]] = []
    @State private var currentPoints: [CGPoint] = []
    @State private var coveragePercent: CGFloat = 0
    @State private var isComplete = false
    @State private var showReward = false

    // Extracted from the asset image via Vision — same path used for guide + hit detection
    @State private var outlinePath: CGPath? = nil
    @State private var hitZonePath: CGPath? = nil
    @State private var outlineSamples: [CGPoint] = []
    @State private var hitSamples: Set<Int> = []

    private var activity: DrawActivity { DrawActivity.all[activityIndex] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)

                if showAllDone {
                    AllDoneView(completedCount: completedCount, geo: geo) {
                        dismiss()
                    }
                    .transition(.opacity)
                    .zIndex(3)
                } else if showReward {
                    RewardView(
                        word: activity.word,
                        imageName: activity.imageName,
                        modelName: activity.modelName,
                        geo: geo,
                        isLastActivity: activityIndex == DrawActivity.all.count - 1
                    ) {
                        advanceActivity(geo: geo)
                    }
                    .transition(.opacity)
                    .zIndex(2)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            BackButton { dismiss() }
                            Spacer()
                            // Progress dots
                            HStack(spacing: geo.size.width * 0.008) {
                                ForEach(0..<DrawActivity.all.count, id: \.self) { i in
                                    Circle()
                                        .fill(
                                            i < completedCount
                                            ? Color(red: 0.18, green: 0.65, blue: 0.35)
                                            : i == activityIndex
                                            ? Color.appOrange
                                            : Color.appCardBorder
                                        )
                                        .frame(
                                            width:  i == activityIndex ? geo.size.width * 0.016 : geo.size.width * 0.010,
                                            height: i == activityIndex ? geo.size.width * 0.016 : geo.size.width * 0.010
                                        )
                                        .animation(.spring(response: 0.28), value: activityIndex)
                                }
                            }
                            Spacer()
                            // Invisible spacer to balance back button
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, geo.size.width * 0.03)
                        .padding(.top, geo.size.height * 0.02)

                        Spacer(minLength: geo.size.height * 0.01)

                        // Reference image above the card — full colour, small
                        Image(activity.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.14, 110))
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                        Spacer(minLength: geo.size.height * 0.015)

                        drawingCard(geo: geo)
                            .padding(.horizontal, geo.size.width * 0.04)

                        Spacer(minLength: geo.size.height * 0.04)
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            let total = DrawActivity.all.count
            if savedCount >= total {
                // Already finished all — restart from scratch
                completedCount = 0
                activityIndex = 0
                savedCount = 0
            } else {
                completedCount = savedCount
                activityIndex = savedCount
            }
        }
    }

    private func advanceActivity(geo: GeometryProxy) {
        completedCount += 1
        savedCount = completedCount
        let next = activityIndex + 1
        if next >= DrawActivity.all.count {
            withAnimation(.easeInOut(duration: 0.45)) { showAllDone = true }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { showReward = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                resetRound()
                activityIndex = next
            }
        }
    }

    private func loadOutline(imgName: String, cardW: CGFloat, cardH: CGFloat) {
        // Compute outlineRect fresh here so we always use the correct image dimensions
        let outlineMaxW = cardW * 0.70
        let outlineMaxH = cardH * 0.80
        let rect = centredRect(
            imageNamed: imgName,
            maxW: outlineMaxW, maxH: outlineMaxH,
            cardW: cardW, cardH: cardH
        )
        print("[DRAW] loadOutline \(imgName) rect=\(rect)")
        DispatchQueue.global(qos: .userInitiated).async {
            let path = extractOutlinePath(imageNamed: imgName, scaledTo: rect)
            print("[DRAW] path for \(imgName): \(path == nil ? "NIL" : "OK \(path!.boundingBox)")")
            guard let p = path else { return }
            let hz = p.copy(strokingWithWidth: 24, lineCap: .round, lineJoin: .round, miterLimit: 10)
            let samples = samplePath(p, count: 400)
            DispatchQueue.main.async {
                outlinePath    = p
                hitZonePath    = hz
                outlineSamples = samples
            }
        }
    }

    private func resetRound() {
        strokes = []; currentPoints = []; coveragePercent = 0
        isComplete = false; showReward = false
        outlinePath = nil; hitZonePath = nil
        outlineSamples = []; hitSamples = []
    }

    // MARK: - Drawing card

    @ViewBuilder
    private func drawingCard(geo: GeometryProxy) -> some View {
        let cardW   = geo.size.width  * 0.92
        let cardH   = geo.size.height * 0.52
        let radius  = min(geo.size.width * 0.025, 22)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.95).opacity(0.95))
                .shadow(color: Color.appCardBorder.opacity(0.3), radius: 10, x: 0, y: 4)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.appCardBorder, lineWidth: 2)

            // Dashed guide — drawn from the Vision-extracted path
            if let outline = outlinePath {
                Path(outline)
                    .stroke(Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.65),
                            style: StrokeStyle(lineWidth: 5, dash: [14, 8]))
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }

            // User strokes
            Canvas { ctx, _ in
                let style = StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                let color = GraphicsContext.Shading.color(
                    Color(red: 0.85, green: 0.28, blue: 0.28).opacity(0.85))
                for pts in strokes {
                    guard pts.count > 1 else { continue }
                    var path = Path(); path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                    ctx.stroke(path, with: color, style: style)
                }
                if currentPoints.count > 1 {
                    var path = Path(); path.move(to: currentPoints[0])
                    currentPoints.dropFirst().forEach { path.addLine(to: $0) }
                    ctx.stroke(path, with: color, style: style)
                }
            }
            .frame(width: cardW, height: cardH)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            // "DRAW!" hint
            if coveragePercent < 0.08 {
                Text("DRAW!")
                    .font(.app(size: min(geo.size.width * 0.04, 36)))
                    .foregroundStyle(Color(red: 0.75, green: 0.62, blue: 0.48).opacity(0.55))
                    .opacity(Double(max(0, 1.0 - coveragePercent / 0.08)))
                    .allowsHitTesting(false)
            }

            // Progress ring
            if coveragePercent > 0.02 && !isComplete {
                ProgressRing(progress: min(coveragePercent, 1.0))
                    .frame(width: 50, height: 50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cardW, height: cardH)
        .onAppear {
            loadOutline(imgName: activity.imageName, cardW: cardW, cardH: cardH)
        }
        .onChange(of: activityIndex) { newIndex in
            loadOutline(imgName: DrawActivity.all[newIndex].imageName, cardW: cardW, cardH: cardH)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { val in
                    guard !isComplete else { return }
                    currentPoints.append(val.location)
                    checkPoint(val.location)
                }
                .onEnded { _ in
                    guard !isComplete else { return }
                    if !currentPoints.isEmpty { strokes.append(currentPoints) }
                    currentPoints = []
                }
        )
    }

    // MARK: - Hit testing

    private func checkPoint(_ pt: CGPoint) {
        guard let zone = hitZonePath, !outlineSamples.isEmpty else { return }
        guard zone.contains(pt) else { return }

        var nearest = -1
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, sample) in outlineSamples.enumerated() {
            guard !hitSamples.contains(i) else { continue }
            let dx = pt.x - sample.x, dy = pt.y - sample.y
            let d = dx*dx + dy*dy
            if d < bestDist { bestDist = d; nearest = i }
        }
        if nearest >= 0 && bestDist < 16*16 {
            hitSamples.insert(nearest)
            let pct = CGFloat(hitSamples.count) / CGFloat(outlineSamples.count)
            coveragePercent = pct
            if pct >= 0.88 && !isComplete {
                isComplete = true
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.55)) { showReward = true }
                }
            }
        }
    }
}

// MARK: - Outline extraction

/// Extracts the outer silhouette CGPath from any PNG with transparent background.
/// Binarises the alpha channel, adds 15% padding, renders via UIGraphicsImageRenderer,
/// then runs VNDetectContoursRequest to find the shape silhouette.
private func extractOutlinePath(imageNamed name: String, scaledTo targetRect: CGRect) -> CGPath? {
    #if os(iOS)
    guard let uiImage = UIImage(named: name), let cgImage = uiImage.cgImage else { return nil }

    let origW = cgImage.width
    let origH = cgImage.height
    guard origW > 0, origH > 0 else { return nil }

    // ── 1. Read RGBA pixels into malloc buffer ────────────────────────────────
    guard let srcBuf = calloc(origW * origH * 4, 1) else { return nil }
    defer { free(srcBuf) }
    let srcPixels = srcBuf.bindMemory(to: UInt8.self, capacity: origW * origH * 4)
    guard let rgbaCtx = CGContext(data: srcBuf, width: origW, height: origH,
                                  bitsPerComponent: 8, bytesPerRow: origW * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    rgbaCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: origW, height: origH))

    // ── 2. Build padded binary mask (dark shape on white background for Vision) ─
    let pad  = 0.30
    let pw   = Int(Double(origW) * (1 + pad * 2))
    let ph   = Int(Double(origH) * (1 + pad * 2))
    let padX = Int(Double(origW) * pad)
    let padY = Int(Double(origH) * pad)

    guard let maskBuf = calloc(ph * pw, 1) else { return nil }
    defer { free(maskBuf) }
    let maskPtr = maskBuf.bindMemory(to: UInt8.self, capacity: ph * pw)
    memset(maskBuf, 255, ph * pw)                // white background
    for row in 0..<origH {
        for col in 0..<origW {
            if srcPixels[(row * origW + col) * 4 + 3] > 30 {
                maskPtr[(row + padY) * pw + (col + padX)] = 0   // black shape
            }
        }
    }
    guard let maskCtx = CGContext(data: maskBuf, width: pw, height: ph,
                                  bitsPerComponent: 8, bytesPerRow: pw,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)),
          let greyImage = maskCtx.makeImage()
    else { return nil }

    // ── 3. Run Vision ─────────────────────────────────────────────────────────
    let request = VNDetectContoursRequest()
    request.contrastAdjustment = 3.0
    request.maximumImageDimension = 512
    let handler = VNImageRequestHandler(cgImage: greyImage, orientation: .up, options: [:])
    guard (try? handler.perform([request])) != nil,
          let obs = request.results?.first as? VNContoursObservation else {
        print("[VISION] no observation for \(name)"); return nil
    }
    print("[VISION] \(name): \(obs.topLevelContours.count) top-level contours")

    // ── 4. Pick the outer silhouette contour ──────────────────────────────────
    // Strategy: the outer silhouette has the largest bounding box.
    // But first flatten all contours (top-level + children) to find the true outer edge.
    // Skip any contour that spans >95% of canvas in both dims (image border artifact).
    var allContours: [VNContour] = []
    func collect(_ contours: [VNContour]) {
        for c in contours {
            allContours.append(c)
            collect(c.childContours)
        }
    }
    collect(obs.topLevelContours)

    var best: VNContour? = nil
    var bestArea: Float = 0
    for c in allContours {
        let bb = c.normalizedPath.boundingBox
        if bb.width > 0.95 && bb.height > 0.95 { continue }
        let area = Float(bb.width * bb.height)
        if area > bestArea { bestArea = area; best = c }
    }
    guard let contour = best else {
        print("[VISION] \(name): no suitable contour from \(allContours.count) total")
        return nil
    }
    print("[VISION] \(name): chose contour bb=\(contour.normalizedPath.boundingBox)")

    // ── 5. Map Vision normalised coords → targetRect ──────────────────────────
    // The contour's normalised bounding box tells us exactly where the shape sits.
    // Scale that bounding box to fill targetRect precisely — no over/under scaling.
    let cBB = contour.normalizedPath.boundingBox
    // Vision Y is flipped (origin bottom-left). In Vision space:
    //   visually top of shape = cBB.minY (small Y = bottom in Vision = top visually)
    // Map: Vision x in [cBB.minX .. cBB.maxX] → targetRect x range
    //       Vision y in [cBB.minY .. cBB.maxY] → targetRect y range (flipped)
    let scaleX = targetRect.width  / cBB.width
    let scaleY = targetRect.height / cBB.height
    // Step 1: shift so contour starts at (0,0)
    // Step 2: scale to targetRect size, flip Y
    // Step 3: translate to targetRect origin (after Y flip, add height to correct direction)
    var transform = CGAffineTransform(translationX: -cBB.minX, y: -cBB.minY)
        .concatenating(CGAffineTransform(scaleX: scaleX, y: -scaleY))
        .concatenating(CGAffineTransform(translationX: targetRect.origin.x,
                                         y: targetRect.origin.y + targetRect.height))
    return contour.normalizedPath.copy(using: &transform)
    #else
    return nil
    #endif
}

// MARK: - Geometry helpers

/// Compute a centred CGRect that fits the image's aspect ratio within maxW×maxH,
/// positioned in the centre of the card.
private func centredRect(imageNamed name: String, maxW: CGFloat, maxH: CGFloat,
                          cardW: CGFloat, cardH: CGFloat) -> CGRect {
    #if os(iOS)
    let size = UIImage(named: name)?.size ?? CGSize(width: maxW, height: maxH)
    #else
    let size = CGSize(width: maxW, height: maxH)
    #endif
    let aspect = size.width / size.height
    var w = maxW, h = maxW / aspect
    if h > maxH { h = maxH; w = maxH * aspect }
    return CGRect(x: (cardW - w) / 2, y: (cardH - h) / 2, width: w, height: h)
}

// MARK: - Path sampler

private func samplePath(_ cgPath: CGPath, count: Int) -> [CGPoint] {
    var poly: [CGPoint] = []
    cgPath.applyWithBlock { el in
        switch el.pointee.type {
        case .moveToPoint:
            poly.append(el.pointee.points[0])
        case .addLineToPoint:
            poly.append(el.pointee.points[0])
        case .addCurveToPoint:
            let p0 = poly.last ?? .zero
            let cp1 = el.pointee.points[0]
            let cp2 = el.pointee.points[1]
            let p3  = el.pointee.points[2]
            for k in 1...30 {
                let t = CGFloat(k) / 30
                let u = 1 - t
                let uu = u*u; let tt = t*t
                let uuu = uu*u; let ttt = tt*t
                let x = uuu*p0.x + 3*uu*t*cp1.x + 3*u*tt*cp2.x + ttt*p3.x
                let y = uuu*p0.y + 3*uu*t*cp1.y + 3*u*tt*cp2.y + ttt*p3.y
                poly.append(CGPoint(x: x, y: y))
            }
        case .addQuadCurveToPoint:
            let p0 = poly.last ?? .zero
            let cp = el.pointee.points[0]
            let p2 = el.pointee.points[1]
            for k in 1...20 {
                let t = CGFloat(k) / 20
                let u = 1 - t
                let x = u*u*p0.x + 2*u*t*cp.x + t*t*p2.x
                let y = u*u*p0.y + 2*u*t*cp.y + t*t*p2.y
                poly.append(CGPoint(x: x, y: y))
            }
        default: break
        }
    }
    guard poly.count > 1 else { return poly }
    var arc: [CGFloat] = [0]
    for i in 1..<poly.count {
        let dx = poly[i].x - poly[i-1].x
        let dy = poly[i].y - poly[i-1].y
        arc.append(arc[i-1] + sqrt(dx*dx + dy*dy))
    }
    let total = arc.last!
    guard total > 0 else { return poly }
    var result: [CGPoint] = []; var j = 0
    for k in 0..<count {
        let target = total * CGFloat(k) / CGFloat(count - 1)
        while j < arc.count - 1 && arc[j+1] < target { j += 1 }
        if j >= poly.count - 1 { result.append(poly.last!) }
        else {
            let span = arc[j+1] - arc[j]
            let t = span > 0 ? (target - arc[j]) / span : 0
            result.append(CGPoint(x: poly[j].x + t*(poly[j+1].x - poly[j].x),
                                  y: poly[j].y + t*(poly[j+1].y - poly[j].y)))
        }
    }
    return result
}

// MARK: - Progress ring

private struct ProgressRing: View {
    let progress: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(Color.appCardBorder.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(Color(red: 0.18, green: 0.62, blue: 0.32),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

// MARK: - Reward view

private struct RewardView: View {
    let word: String
    let imageName: String   // 2D PNG fallback
    let modelName: String   // USDZ name
    let geo: GeometryProxy
    let isLastActivity: Bool
    let onContinue: () -> Void
    @State private var modelVisible = false
    @State private var labelVisible = false

    // True if a USDZ file for this activity is bundled
    private var hasModel: Bool {
        Bundle.main.url(forResource: modelName, withExtension: "usdz") != nil
    }

    var body: some View {
        VStack(spacing: geo.size.height * 0.025) {
            Spacer()
            #if os(iOS)
            if hasModel {
                ModelRealityView(modelName: modelName)
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
                    Text(isLastActivity ? "ALL DONE!" : "NEXT DRAWING")
                        .font(.app(size: min(geo.size.width * 0.025, 22)))
                    if !isLastActivity {
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
        .onAppear { modelVisible = true; labelVisible = true }
    }
}

// MARK: - All Done celebration screen (Draw)

private struct AllDoneView: View {
    let completedCount: Int
    let geo: GeometryProxy
    let onDismiss: () -> Void

    @State private var starScale: CGFloat = 0.3
    @State private var starOpacity: Double = 0
    @State private var labelVisible = false
    @State private var floatY: CGFloat = 0

    var body: some View {
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
                Text("YOU'RE A STAR!")
                    .font(.app(size: min(geo.size.width * 0.07, 58)))
                    .foregroundStyle(Color.appOrange)
                    .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)

                Text("You drew \(completedCount) picture\(completedCount == 1 ? "" : "s")!")
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

// MARK: - RealityKit 3D model (generic — uses modelName.usdz)

#if os(iOS)
private struct ModelRealityView: UIViewRepresentable {
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
        let pan = UIPanGestureRecognizer(target: coord, action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(pan)

        // Pinch to zoom
        let pinch = UIPinchGestureRecognizer(target: coord, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
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
                // Clamp vertical rotation so kids don't flip it upside-down
                rotationX = min(max(rotationX, -.pi / 3), .pi / 3)
                let qX = simd_quatf(angle: rotationX, axis: [1, 0, 0])
                let qY = simd_quatf(angle: rotationY, axis: [0, 1, 0])
                model.transform.rotation = qY * qX
                gesture.setTranslation(.zero, in: gesture.view)
            case .ended, .cancelled:
                // Resume idle spin after 2 seconds
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
}
#endif
