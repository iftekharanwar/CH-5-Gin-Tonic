import SwiftUI
#if os(iOS)
import RealityKit
import Vision
import UIKit
#endif
import Combine

// MARK: - DrawActivity

struct DrawActivity {
    let imageName: String
    let word: String
    let modelName: String

    init(imageName: String, word: String, modelName: String? = nil) {
        self.imageName = imageName
        self.word = word
        self.modelName = modelName ?? imageName
    }

    static let all: [DrawActivity] = [
        DrawActivity(imageName: "apple", word: "APPLE"),
        DrawActivity(imageName: "star",  word: "STAR"),
        DrawActivity(imageName: "book",  word: "BOOK"),
        DrawActivity(imageName: "cup",   word: "CUP"),
        DrawActivity(imageName: "dog",   word: "DOG"),
    ]
}

// MARK: - LetsDrawView

struct LetsDrawView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = WordSpeaker()

    @AppStorage("drawCompletedCount") private var savedCount = 0
    @State private var activityIndex = 0
    @State private var completedCount = 0
    @State private var showAllDone = false

    @State private var strokes: [[CGPoint]] = []
    @State private var strokeColors: [Color] = []
    @State private var currentPoints: [CGPoint] = []
    @State private var coveragePercent: CGFloat = 0
    @State private var isComplete = false
    @State private var showReward = false
    @State private var selectedColor: Color = Color(red: 0.85, green: 0.28, blue: 0.28)

    private static let presetColors: [Color] = [
        Color(red: 0.85, green: 0.28, blue: 0.28),
        Color(red: 0.20, green: 0.50, blue: 0.85),
        Color(red: 0.18, green: 0.65, blue: 0.35),
        Color(red: 0.90, green: 0.55, blue: 0.10),
        Color(red: 0.60, green: 0.30, blue: 0.70),
    ]

    @State private var outlinePath: CGPath? = nil
    @State private var hitZonePath: CGPath? = nil
    @State private var outlineSamples: [CGPoint] = []
    @State private var hitSamples: Set<Int> = []

    @State private var lastCardW: CGFloat = 0
    @State private var lastCardH: CGFloat = 0

    @State private var mascotVisible = false
    @State private var mascotBounce: CGFloat = 0
    @State private var lastMilestone = 0
    @State private var mascotSpeech: String? = nil
    @State private var showMascotSpeech = false
    @State private var earnedStars = 0
    @State private var showLeaveAlert = false

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
                        stars: earnedStars,
                        geo: geo,
                        isLastActivity: activityIndex == DrawActivity.all.count - 1
                    ) {
                        advanceActivity(geo: geo)
                    }
                    .transition(.opacity)
                    .zIndex(2)
                } else {
                    let isLand = geo.size.width > geo.size.height
                    let minDim = min(geo.size.width, geo.size.height)
                    VStack(spacing: 0) {
                        HStack {
                            BackButton {
                                if strokes.isEmpty {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showLeaveAlert = true }
                                }
                            }
                            Spacer()
                            HStack(spacing: minDim * 0.008) {
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
                                            width:  i == activityIndex ? minDim * 0.016 : minDim * 0.010,
                                            height: i == activityIndex ? minDim * 0.016 : minDim * 0.010
                                        )
                                        .animation(.spring(response: 0.28), value: activityIndex)
                                }
                            }
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, geo.size.width * 0.03)
                        .padding(.top, geo.size.height * 0.02)

                        Spacer(minLength: geo.size.height * 0.01)

                        Image(activity.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(
                                isLand ? geo.size.height * 0.22 : geo.size.height * 0.18,
                                180
                            ))
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                        Spacer(minLength: geo.size.height * 0.005)

                        drawToolbar(geo: geo)

                        Spacer(minLength: geo.size.height * 0.005)

                        drawingCard(geo: geo)
                            .padding(.horizontal, geo.size.width * 0.04)

                        Spacer(minLength: isLand ? geo.size.height * 0.04 : geo.size.height * 0.02)
                    }

                    if mascotVisible {
                        let starSize = minDim * 0.14
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
                }
            }
        }
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .overlay {
            if showLeaveAlert {
                LeaveDrawingAlert(
                    onStay: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showLeaveAlert = false } },
                    onLeave: { dismiss() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .zIndex(200)
            }
        }
        .onAppear {
            let total = DrawActivity.all.count
            if savedCount >= total {
                completedCount = 0
                activityIndex = 0
                savedCount = 0
            } else {
                completedCount = savedCount
                activityIndex = savedCount
            }
            #if os(iOS)
            ModelCache.shared.preload(activity.modelName)
            #endif
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
        strokes = []; strokeColors = []; currentPoints = []; coveragePercent = 0
        isComplete = false; showReward = false
        outlinePath = nil; hitZonePath = nil
        outlineSamples = []; hitSamples = []
        lastCardW = 0; lastCardH = 0
        mascotVisible = false; mascotBounce = 0; lastMilestone = 0
        mascotSpeech = nil; showMascotSpeech = false
        selectedColor = Self.presetColors[0]
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

    // MARK: - Draw toolbar

    @ViewBuilder
    private func drawToolbar(geo: GeometryProxy) -> some View {
        let minDim = min(geo.size.width, geo.size.height)
        let dotSize: CGFloat = min(minDim * 0.05, 34)
        HStack(spacing: minDim * 0.02) {
            ForEach(Self.presetColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                    )
                    .shadow(color: selectedColor == color ? color.opacity(0.6) : .clear, radius: 6)
                    .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectedColor)
                    .onTapGesture {
                        selectedColor = color
                        SoundPlayer.shared.play(.tap)
                    }
            }

            Spacer().frame(width: minDim * 0.02)

            Button {
                undoLastStroke()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: dotSize * 0.85, weight: .bold))
                    .foregroundStyle(strokes.isEmpty ? Color.gray.opacity(0.4) : Color(red: 0.52, green: 0.30, blue: 0.10))
            }
            .buttonStyle(.plain)
            .disabled(strokes.isEmpty || isComplete)
        }
        .padding(.horizontal, geo.size.width * 0.06)
    }

    private func undoLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        strokeColors.removeLast()
        recalculateCoverage()
        SoundPlayer.shared.play(.pop)
    }

    private func recalculateCoverage() {
        hitSamples.removeAll()
        guard let zone = hitZonePath, !outlineSamples.isEmpty else {
            coveragePercent = 0; return
        }
        for pts in strokes {
            for pt in pts {
                guard zone.contains(pt) else { continue }
                checkPointSilent(pt)
            }
        }
        coveragePercent = outlineSamples.isEmpty ? 0 : CGFloat(hitSamples.count) / CGFloat(outlineSamples.count)
        let milestone = Int(coveragePercent * 100) / 25
        lastMilestone = milestone
        isComplete = coveragePercent >= 0.88
    }

    private func checkPointSilent(_ pt: CGPoint) {
        guard !outlineSamples.isEmpty else { return }
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
        }
    }

    // MARK: - Drawing card

    @ViewBuilder
    private func drawingCard(geo: GeometryProxy) -> some View {
        let isLand  = geo.size.width > geo.size.height
        let cardW   = geo.size.width * 0.92
        let cardH   = isLand ? geo.size.height * 0.52 : geo.size.height * 0.55
        let radius  = min(min(geo.size.width, geo.size.height) * 0.025, 22)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.95).opacity(0.95))
                .shadow(color: Color.appCardBorder.opacity(0.3), radius: 10, x: 0, y: 4)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.appCardBorder, lineWidth: 2)

            if let outline = outlinePath {
                Path(outline)
                    .stroke(Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.65),
                            style: StrokeStyle(lineWidth: 5, dash: [14, 8]))
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }

            Canvas { ctx, _ in
                let style = StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                for (idx, pts) in strokes.enumerated() {
                    guard pts.count > 1 else { continue }
                    let c = idx < strokeColors.count ? strokeColors[idx] : Self.presetColors[0]
                    var path = Path(); path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                    ctx.stroke(path, with: .color(c.opacity(0.85)), style: style)
                }
                if currentPoints.count > 1 {
                    var path = Path(); path.move(to: currentPoints[0])
                    currentPoints.dropFirst().forEach { path.addLine(to: $0) }
                    ctx.stroke(path, with: .color(selectedColor.opacity(0.85)), style: style)
                }
            }
            .frame(width: cardW, height: cardH)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            if coveragePercent < 0.08 {
                Text("DRAW!")
                    .font(.app(size: min(min(geo.size.width, geo.size.height) * 0.05, 36)))
                    .foregroundStyle(Color(red: 0.75, green: 0.62, blue: 0.48).opacity(0.55))
                    .opacity(Double(max(0, 1.0 - coveragePercent / 0.08)))
                    .allowsHitTesting(false)
            }

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
            lastCardW = cardW; lastCardH = cardH
            loadOutline(imgName: activity.imageName, cardW: cardW, cardH: cardH)
        }
        .onChange(of: activityIndex) { _, newIndex in
            loadOutline(imgName: DrawActivity.all[newIndex].imageName, cardW: cardW, cardH: cardH)
        }
        .onChange(of: geo.size) { _, _ in
            let newW = geo.size.width * 0.92
            let newIsLand = geo.size.width > geo.size.height
            let newH = newIsLand ? geo.size.height * 0.52 : geo.size.height * 0.55
            if abs(newW - lastCardW) > 2 || abs(newH - lastCardH) > 2 {
                lastCardW = newW; lastCardH = newH
                strokes = []; strokeColors = []; currentPoints = []; hitSamples = []
                coveragePercent = 0
                outlinePath = nil; hitZonePath = nil; outlineSamples = []
                loadOutline(imgName: activity.imageName, cardW: newW, cardH: newH)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { val in
                    guard !isComplete else { return }
                    if !mascotVisible {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            mascotVisible = true
                        }
                    }
                    currentPoints.append(val.location)
                    checkPoint(val.location)
                }
                .onEnded { _ in
                    guard !isComplete else { return }
                    if !currentPoints.isEmpty {
                        strokes.append(currentPoints)
                        strokeColors.append(selectedColor)
                    }
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

            let milestone = Int(pct * 100) / 25
            if milestone > lastMilestone && milestone < 4 {
                lastMilestone = milestone
                SoundPlayer.shared.play(.pop)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.25, dampingFraction: 0.3)) {
                    mascotBounce = -20
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        mascotBounce = 0
                    }
                }
                let milestoneMessages = ["Keep going!", "Halfway there!", "Almost done!"]
                let msg = milestoneMessages[min(milestone - 1, 2)]
                showMascotMessage(msg)
                speaker.speak(msg)
            }

            if pct >= 0.88 && !isComplete {
                isComplete = true
                earnedStars = AchievementStore.drawStars(coverage: pct)
                AchievementStore.shared.setStars(activity: activity.imageName, type: "draw", stars: earnedStars)
                SoundPlayer.shared.play(.success)
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                let doneMsg = "Amazing! You drew a \(activity.word.lowercased())!"
                showMascotMessage(doneMsg)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    speaker.spellThenSpeak(activity.word)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    SoundPlayer.shared.play(.whoosh)
                    withAnimation(.easeInOut(duration: 0.55)) { showReward = true }
                }
            }
        }
    }
}

// MARK: - Outline extraction

private func extractOutlinePath(imageNamed name: String, scaledTo targetRect: CGRect) -> CGPath? {
    #if os(iOS)
    guard let uiImage = UIImage(named: name), let cgImage = uiImage.cgImage else { return nil }

    let origW = cgImage.width
    let origH = cgImage.height
    guard origW > 0, origH > 0 else { return nil }

    guard let srcBuf = calloc(origW * origH * 4, 1) else { return nil }
    defer { free(srcBuf) }
    let srcPixels = srcBuf.bindMemory(to: UInt8.self, capacity: origW * origH * 4)
    guard let rgbaCtx = CGContext(data: srcBuf, width: origW, height: origH,
                                  bitsPerComponent: 8, bytesPerRow: origW * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    rgbaCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: origW, height: origH))

    // Padded binary mask: dark shape on white background for Vision
    let pad  = 0.30
    let pw   = Int(Double(origW) * (1 + pad * 2))
    let ph   = Int(Double(origH) * (1 + pad * 2))
    let padX = Int(Double(origW) * pad)
    let padY = Int(Double(origH) * pad)

    guard let maskBuf = calloc(ph * pw, 1) else { return nil }
    defer { free(maskBuf) }
    let maskPtr = maskBuf.bindMemory(to: UInt8.self, capacity: ph * pw)
    memset(maskBuf, 255, ph * pw)
    for row in 0..<origH {
        for col in 0..<origW {
            if srcPixels[(row * origW + col) * 4 + 3] > 30 {
                maskPtr[(row + padY) * pw + (col + padX)] = 0
            }
        }
    }
    guard let maskCtx = CGContext(data: maskBuf, width: pw, height: ph,
                                  bitsPerComponent: 8, bytesPerRow: pw,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)),
          let greyImage = maskCtx.makeImage()
    else { return nil }

    let request = VNDetectContoursRequest()
    request.contrastAdjustment = 3.0
    request.maximumImageDimension = 512
    let handler = VNImageRequestHandler(cgImage: greyImage, orientation: .up, options: [:])
    guard (try? handler.perform([request])) != nil,
          let obs = request.results?.first as? VNContoursObservation else {
        print("[VISION] no observation for \(name)"); return nil
    }
    print("[VISION] \(name): \(obs.topLevelContours.count) top-level contours")

    // Pick the largest contour (skip image border artifacts >95%)
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

    // Map Vision normalised coords (bottom-left origin, Y-up) → targetRect
    let cBB = contour.normalizedPath.boundingBox
    let scaleX = targetRect.width  / cBB.width
    let scaleY = targetRect.height / cBB.height
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
    let imageName: String
    let modelName: String
    let stars: Int
    let geo: GeometryProxy
    let isLastActivity: Bool
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
                    Text(isLastActivity ? "ALL DONE!" : "NEXT DRAWING")
                        .font(.app(size: min(minDim * 0.035, 22)))
                    if !isLastActivity {
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

private struct AllDoneView: View {
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
                Text("YOU'RE A STAR!")
                    .font(.app(size: min(minDim * 0.10, 58)))
                    .foregroundStyle(Color.appOrange)
                    .shadow(color: Color.appOrange.opacity(0.25), radius: 6, x: 0, y: 3)

                Text("You drew \(completedCount) picture\(completedCount == 1 ? "" : "s")!")
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
        .frame(width: geo.size.width, height: geo.size.height)

            ConfettiView()
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
        }
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

// MARK: - Leave Drawing Alert

private struct LeaveDrawingAlert: View {
    let onStay: () -> Void
    let onLeave: () -> Void

    @State private var pressed: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onStay() }

            VStack(spacing: 0) {
                Image("startmascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .offset(y: 20)
                    .zIndex(1)

                VStack(spacing: 16) {
                    Text("Wait!")
                        .font(.app(size: 28))
                        .foregroundStyle(Color.appOrange)
                        .padding(.top, 24)

                    Text("Your drawing will be lost!")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.30))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Button {
                            onStay()
                        } label: {
                            Text("Keep Drawing")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.18, green: 0.65, blue: 0.35))
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(pressed == "stay" ? 0.92 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in pressed = "stay" }
                                .onEnded { _ in pressed = nil }
                        )

                        Button {
                            onLeave()
                        } label: {
                            Text("Leave")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.25))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.85, green: 0.30, blue: 0.25).opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color(red: 0.85, green: 0.30, blue: 0.25).opacity(0.3), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(pressed == "leave" ? 0.92 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in pressed = "leave" }
                                .onEnded { _ in pressed = nil }
                        )
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.appCardBorder.opacity(0.4), lineWidth: 1.5)
                )
            }
            .frame(maxWidth: 320)
        }
    }
}
