import SwiftUI
import CoreText
import CoreGraphics

// MARK: - Alphabet Model

struct AlphabetTraceActivity: Identifiable, Hashable {
    let id = UUID()
    let upper: Character
    let lower: Character
    
    static let all: [AlphabetTraceActivity] = [
        ("A","a"), ("B","b"), ("C","c"), ("D","d"),
        ("E","e"), ("F","f"), ("G","g"), ("H","h"),
        ("I","i"), ("J","j"), ("K","k"), ("L","l"),
        ("M","m"), ("N","n"), ("O","o"), ("P","p"),
        ("Q","q"), ("R","r"), ("S","s"), ("T","t"),
        ("U","u"), ("V","v"), ("W","w"), ("X","x"),
        ("Y","y"), ("Z","z")
    ].map { AlphabetTraceActivity(upper: Character($0.0), lower: Character($0.1)) }
}

// MARK: - Main View

struct AlphabetTraceView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("traceCompletedCount") private var traceCompleted = 0
    
    @State private var index = 0
    @State private var showUppercase = true
    
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var selectedColor: Color = .blue
    @State private var showSuccess = false
    @State private var showAllDone = false
    
    @State private var scaledLetterPath: CGPath?
    @State private var letterBounds: CGRect = .zero
    
    @StateObject private var speaker = WordSpeaker()
    
    private var item: AlphabetTraceActivity {
        AlphabetTraceActivity.all[index]
    }
    
    private var letter: Character {
        showUppercase ? item.upper : item.lower
    }
    
    var body: some View {
        ZStack {
            
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            if showAllDone {
                GeometryReader { geo in
                    AllDoneView(completedCount: index, geo: geo) {
                        dismiss()
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            } else {
                GeometryReader { geo in
                    VStack(spacing: 12) {
                        
                        header
                        
                        traceBoard
                            .frame(
                                maxWidth: min(geo.size.width * 0.9, 900),
                                maxHeight: geo.size.height * 0.50
                            )
                        
                        controls
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                BackButton {
                    dismiss()
                }
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            
            VStack(spacing: 6) {
                
                Text("Trace the letter")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.orange)
                
                HStack(spacing: 10) {
                    
                    Text("\(String(item.upper))  \(String(item.lower))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Button {
                        speaker.speakLetter(letter)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Trace Board
    
    private var traceBoard: some View {
        ZStack {
            
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )
            
            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let fontSize = min(rect.width, rect.height) * 0.6
                
                ZStack {
                    
                    Canvas { ctx, size in
                        let style = StrokeStyle(
                            lineWidth: max(18, fontSize * 0.06),
                            lineCap: .round,
                            lineJoin: .round
                        )
                        
                        // Draw the letter outline as a guide
                        if let letterPath = scaledLetterPath {
                            ctx.stroke(
                                Path(letterPath),
                                with: .color(.gray.opacity(0.25)),
                                style: style
                            )
                        }
                        
                        // Draw completed strokes
                        for stroke in strokes {
                            guard stroke.count > 1 else { continue }
                            var path = Path()
                            path.addLines(stroke)
                            ctx.stroke(path, with: .color(selectedColor), style: style)
                        }
                        
                        // Draw current stroke
                        if currentStroke.count > 1 {
                            var path = Path()
                            path.addLines(currentStroke)
                            ctx.stroke(path, with: .color(selectedColor), style: style)
                        }
                    }
                    .onAppear {
                        prepareLetterPath(for: rect, fontSize: fontSize)
                    }
                    .onChange(of: letter) {
                        prepareLetterPath(for: rect, fontSize: fontSize)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !showSuccess {
                                currentStroke.append(value.location)
                            }
                        }
                        .onEnded { _ in
                            if !currentStroke.isEmpty && !showSuccess {
                                strokes.append(currentStroke)
                                evaluateCompletion()
                            }
                            currentStroke.removeAll()
                        }
                )
            }
        }
        .padding(30)
    }

    private func prepareLetterPath(for rect: CGRect, fontSize: CGFloat) {
        guard let rawPath = getLetterOutline(fontSize: fontSize) else { return }
        
        // Get the bounds of the raw path
        var boundingBox = CGRect.zero
        rawPath.applyWithBlock { element in
            let point = element.pointee.points[0]
            if boundingBox.isEmpty {
                boundingBox = CGRect(x: point.x, y: point.y, width: 0, height: 0)
            } else {
                boundingBox = boundingBox.union(CGRect(x: point.x, y: point.y, width: 0, height: 0))
            }
        }
        
        // Calculate scale to fit the letter in the canvas with some padding
        let padding = rect.width * 0.1
        let availableWidth = rect.width - (padding * 2)
        let availableHeight = rect.height - (padding * 2)
        
        let scaleX = boundingBox.width > 0 ? availableWidth / boundingBox.width : 1
        let scaleY = boundingBox.height > 0 ? availableHeight / boundingBox.height : 1
        let scale = min(scaleX, scaleY)
        
        // Center the letter
        let scaledWidth = boundingBox.width * scale
        let scaledHeight = boundingBox.height * scale
        let offsetX = (rect.width - scaledWidth) / 2 - (boundingBox.minX * scale)
        let offsetY = (rect.height - scaledHeight) / 2 - (boundingBox.minY * scale)
        
        // Create transformation and apply it
        var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.scaledBy(x: 1, y: -1) // Flip vertically
        
        scaledLetterPath = rawPath.copy(using: &transform)
        letterBounds = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
    }

    private func getLetterOutline(fontSize: CGFloat) -> CGPath? {
        let ctFont = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
        
        let string = String(letter)
        var unichar = (string.utf16.first ?? 0)
        var glyph = CGGlyph()
        
        CTFontGetGlyphsForCharacters(ctFont!, &unichar, &glyph, 1)
        
        return CTFontCreatePathForGlyph(ctFont!, glyph, nil)
    }
    
    // MARK: - Completion Logic

    // Add these functions to your view model or view
    
    private func evaluateCompletion() {
        guard let letterPath = scaledLetterPath else {
            print("Letter path not ready yet")
            return
        }
        
        let drawnPoints = strokes.flatMap { $0 }
        
        guard drawnPoints.count > 20 else { return }
        
        let coveragePercentage = calculatePathCoverage(drawnPoints, against: letterPath)
        let proximityScore = calculateProximityScore(drawnPoints, to: letterPath)
        
        print("Check Coverage: \(coveragePercentage * 100)%")
        print("Check Proximity: \(proximityScore * 100)%")
        
        let coverageThreshold: CGFloat = 0.55
        let proximityThreshold: CGFloat = 0.65
        
        let isSuccessful = coveragePercentage > coverageThreshold &&
                          proximityScore > proximityThreshold
        
        if isSuccessful {
            triggerSuccess()
        }
    }

    private func calculatePathCoverage(_ drawnPoints: [CGPoint], against letterPath: CGPath) -> CGFloat {
        let proximityThreshold: CGFloat = 15.0
        let outlinePoints = samplePathPoints(letterPath, sampleCount: 200)
        
        let coveredPoints = outlinePoints.filter { outlinePoint in
            drawnPoints.contains { drawnPoint in
                distance(drawnPoint, to: outlinePoint) <= proximityThreshold
            }
        }
        
        return outlinePoints.isEmpty ? 0 : CGFloat(coveredPoints.count) / CGFloat(outlinePoints.count)
    }

    private func calculateProximityScore(_ drawnPoints: [CGPoint], to letterPath: CGPath) -> CGFloat {
        let proximityThreshold: CGFloat = 20.0
        
        let nearbyPoints = drawnPoints.filter { drawnPoint in
            distance(drawnPoint, to: closestPointOnPath(drawnPoint, path: letterPath)) <= proximityThreshold
        }
        
        return drawnPoints.isEmpty ? 0 : CGFloat(nearbyPoints.count) / CGFloat(drawnPoints.count)
    }

    private func samplePathPoints(_ path: CGPath, sampleCount: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                points.append(element.points[0])
            case .addLineToPoint:
                points.append(element.points[0])
            case .addQuadCurveToPoint:
                // Sample a quad curve
                let start = points.last ?? element.points[0]
                let control = element.points[0]
                let end = element.points[1]
                for i in 1...5 {
                    let t = CGFloat(i) / 5.0
                    let point = quadraticBezier(start, control, end, t: t)
                    points.append(point)
                }
            case .addCurveToPoint:
                // Sample a cubic curve
                let start = points.last ?? element.points[0]
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                for i in 1...10 {
                    let t = CGFloat(i) / 10.0
                    let point = cubicBezier(start, control1, control2, end, t: t)
                    points.append(point)
                }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        return points
    }

    private func closestPointOnPath(_ point: CGPoint, path: CGPath) -> CGPoint {
        var closestPoint = CGPoint.zero
        var closestDistance = CGFloat.greatestFiniteMagnitude
        
        let samplePoints = samplePathPoints(path, sampleCount: 500)
        
        for samplePoint in samplePoints {
            let dist = distance(point, to: samplePoint)
            if dist < closestDistance {
                closestDistance = dist
                closestPoint = samplePoint
            }
        }
        
        return closestPoint.equalTo(.zero) ? point : closestPoint
    }

    // Quadratic Bezier curve
    private func quadraticBezier(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
        let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    // Cubic Bezier curve
    private func cubicBezier(_ start: CGPoint, _ control1: CGPoint, _ control2: CGPoint, _ end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        
        let x = mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x
        let y = mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y
        
        return CGPoint(x: x, y: y)
    }

    private func distance(_ p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func triggerSuccess() {
        guard !showSuccess else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccess = false
            }
            goToNextLetter()
        }
    }
    
    private func goToNextLetter() {
        // Increment completion count
        traceCompleted = index + 1
        
        if index < AlphabetTraceActivity.all.count - 1 {
            index += 1
            clear()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                speaker.speakLetter(letter)
            }
        } else {
            // All 26 alphabets completed
            withAnimation(.easeInOut(duration: 0.3)) {
                showAllDone = true
            }
        }
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        VStack(spacing: 12) {
            
            Button {
                clear()
            } label: {
                Label("Clear", systemImage: "trash")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange)
                    )
            }
            .buttonStyle(.plain)
            
            Picker("Case", selection: $showUppercase) {
                Text("Uppercase").tag(true)
                Text("Lowercase").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .onChange(of: showUppercase) { _, _ in
                clear()
            }
            
            HStack(spacing: 18) {
                ForEach([Color.red, .blue, .green, .orange, .purple, .pink], id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
            
            alphabetStrip
        }
        .padding(.horizontal, 18)
    }
    
    private var alphabetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(AlphabetTraceActivity.all.enumerated()), id: \.offset) { i, it in
                    Button {
                        index = i
                        clear()
                    } label: {
                        Text(showUppercase ? String(it.upper) : String(it.lower))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(i == index ? .black : .gray)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(i == index ? Color.orange : Color.gray.opacity(0.2))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 720)
    }
    
    private func clear() {
        strokes.removeAll()
        currentStroke.removeAll()
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
