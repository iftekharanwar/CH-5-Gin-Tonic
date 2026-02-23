import SwiftUI

struct DrawingGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drawings: [DrawingStorage.DrawingMeta] = []
    @State private var selectedDrawing: DrawingStorage.DrawingMeta? = nil
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let isLand = geo.size.width > geo.size.height

            ZStack {
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    // Top bar
                    ZStack {
                        Text("MY DRAWINGS")
                            .font(.app(size: min(minDim * 0.045, 30)))
                            .foregroundStyle(Color.appOrange)

                        HStack {
                            BackButton { dismiss() }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, geo.size.width * 0.03)
                    .padding(.top, max(geo.safeAreaInsets.top, geo.size.height * 0.04))
                    .padding(.bottom, geo.size.height * 0.015)

                    if drawings.isEmpty {
                        Spacer()
                        emptyState(minDim: minDim)
                        Spacer()
                    } else {
                        let columns = Array(repeating: GridItem(
                            .flexible(),
                            spacing: isLand ? geo.size.width * 0.025 : minDim * 0.03
                        ), count: isLand ? 4 : 3)

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: minDim * 0.03) {
                                ForEach(Array(drawings.enumerated()), id: \.element.id) { i, drawing in
                                    GalleryCell(
                                        drawing: drawing,
                                        cellSize: isLand
                                            ? min(geo.size.width * 0.19, 180)
                                            : min(geo.size.width * 0.27, 200)
                                    ) {
                                        selectedDrawing = drawing
                                    }
                                    .opacity(appeared ? 1 : 0)
                                    .scaleEffect(appeared ? 1 : 0.7)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.7).delay(Double(i) * 0.05),
                                        value: appeared
                                    )
                                }
                            }
                            .padding(.horizontal, geo.size.width * 0.05)
                            .padding(.bottom, geo.size.height * 0.04)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Full screen viewer
                if let selected = selectedDrawing {
                    DrawingViewer(drawing: selected) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDrawing = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(10)
                }
            }
        }
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            drawings = DrawingStorage.shared.allDrawings()
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { appeared = true }
            }
        }
    }

    @ViewBuilder
    private func emptyState(minDim: CGFloat) -> some View {
        VStack(spacing: minDim * 0.03) {
            Image("startmascot")
                .resizable()
                .scaledToFit()
                .frame(width: min(minDim * 0.30, 180))
                .opacity(0.7)

            Text("No drawings yet!")
                .font(.app(size: min(minDim * 0.05, 32)))
                .foregroundStyle(Color.appOrange.opacity(0.7))

            Text("Complete a drawing activity\nto see it here!")
                .font(.system(size: min(minDim * 0.028, 18), weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.35))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Gallery Cell

private struct GalleryCell: View {
    let drawing: DrawingStorage.DrawingMeta
    let cellSize: CGFloat
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: cellSize * 0.05) {
                if let img = DrawingStorage.shared.loadImage(id: drawing.id) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: cellSize * 0.75, height: cellSize * 0.55)
                        .clipShape(RoundedRectangle(cornerRadius: cellSize * 0.06, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cellSize * 0.06, style: .continuous)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.86))
                        .frame(width: cellSize * 0.75, height: cellSize * 0.55)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: cellSize * 0.12))
                                .foregroundStyle(Color(red: 0.70, green: 0.65, blue: 0.58))
                        )
                }

                Text(drawing.word)
                    .font(.app(size: cellSize * 0.12))
                    .foregroundStyle(Color(red: 0.35, green: 0.30, blue: 0.25))
            }
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: cellSize * 0.12, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cellSize * 0.12, style: .continuous)
                    .strokeBorder(Color.appCardBorder.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: Color.appCardBorder.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true } }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Drawing Viewer

private struct DrawingViewer: View {
    let drawing: DrawingStorage.DrawingMeta
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)

            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                VStack(spacing: minDim * 0.025) {
                    HStack {
                        Spacer()
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.35))
                        }
                        .buttonStyle(.plain)
                    }

                    if let img = DrawingStorage.shared.loadImage(id: drawing.id) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                    }

                    Text(drawing.word)
                        .font(.app(size: min(minDim * 0.06, 36)))
                        .foregroundStyle(Color(red: 0.35, green: 0.30, blue: 0.25))
                }
                .padding(minDim * 0.04)
                .frame(maxWidth: min(geo.size.width * 0.85, 600))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.appCardBorder.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            }
        }
    }
}
