import SwiftUI

// MARK: - App font

extension Font {
    static func app(size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        .custom(weight.fontName, size: size)
    }
}

enum AppFontWeight {
    case regular, italic

    var fontName: String {
        switch self {
        case .regular: return "EasyReadingPRO"
        case .italic:  return "EasyReadingPRO-Italic"
        }
    }
}

// MARK: - App colours

extension Color {
    static let appOrange = Color(red: 1.0, green: 0.608, blue: 0.0)
    static let appCardBorder = Color(red: 0.835, green: 0.686, blue: 0.537)
    static let appGoldTop = Color(red: 0.949, green: 0.788, blue: 0.298)
    static let appGoldBottom = Color(red: 0.878, green: 0.486, blue: 0.071)
}
