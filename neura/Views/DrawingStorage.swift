import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Drawing Storage

final class DrawingStorage {
    static let shared = DrawingStorage()

    private let directory: URL = {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedDrawings", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private let metaKey = "drawingGalleryMeta"

    // MARK: - Metadata

    struct DrawingMeta: Codable, Identifiable {
        let id: String
        let word: String
        let imageName: String
        let stars: Int
        let date: Date
    }

    func allDrawings() -> [DrawingMeta] {
        guard let data = UserDefaults.standard.data(forKey: metaKey),
              let list = try? JSONDecoder().decode([DrawingMeta].self, from: data)
        else { return [] }
        return list.sorted { $0.date > $1.date }
    }

    private func saveMeta(_ list: [DrawingMeta]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    // MARK: - Save Drawing

    #if os(iOS)
    func saveDrawing(
        strokes: [[CGPoint]],
        strokeColors: [Color],
        outlinePath: CGPath?,
        cardSize: CGSize,
        word: String,
        imageName: String,
        stars: Int
    ) {
        let id = UUID().uuidString
        let size = cardSize

        // Render drawing to image
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // White background
            UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Draw outline
            if let outline = outlinePath {
                ctx.cgContext.setStrokeColor(UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 0.45).cgColor)
                ctx.cgContext.setLineDash(phase: 0, lengths: [14, 8])
                ctx.cgContext.setLineWidth(4)
                ctx.cgContext.addPath(outline)
                ctx.cgContext.strokePath()
            }

            // Draw strokes
            ctx.cgContext.setLineDash(phase: 0, lengths: [])
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)
            ctx.cgContext.setLineWidth(16)

            for (idx, pts) in strokes.enumerated() {
                guard pts.count > 1 else { continue }
                let color = idx < strokeColors.count ? UIColor(strokeColors[idx]) : UIColor.red
                ctx.cgContext.setStrokeColor(color.withAlphaComponent(0.85).cgColor)
                ctx.cgContext.beginPath()
                ctx.cgContext.move(to: pts[0])
                for p in pts.dropFirst() {
                    ctx.cgContext.addLine(to: p)
                }
                ctx.cgContext.strokePath()
            }
        }

        // Save to disk
        if let pngData = image.pngData() {
            let fileURL = directory.appendingPathComponent("\(id).png")
            try? pngData.write(to: fileURL)
        }

        // Save metadata
        var list = allDrawings()
        let meta = DrawingMeta(id: id, word: word, imageName: imageName, stars: stars, date: Date())
        list.insert(meta, at: 0)
        saveMeta(list)
    }
    #endif

    // MARK: - Load Image

    #if os(iOS)
    func loadImage(id: String) -> UIImage? {
        let fileURL = directory.appendingPathComponent("\(id).png")
        return UIImage(contentsOfFile: fileURL.path)
    }
    #endif

    // MARK: - Delete

    func deleteDrawing(id: String) {
        var list = allDrawings()
        list.removeAll { $0.id == id }
        saveMeta(list)
        let fileURL = directory.appendingPathComponent("\(id).png")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
