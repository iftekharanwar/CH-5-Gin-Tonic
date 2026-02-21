import SwiftUI

// MARK: - App font helper
// Usage: .font(.app(size: 32, weight: .bold))

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

// MARK: - App colour palette

extension Color {
    /// Primary amber/orange — titles, card labels  #FF9B00
    static let appOrange = Color(red: 1.0, green: 0.608, blue: 0.0)

    /// Card border  #D5AF89
    static let appCardBorder = Color(red: 0.835, green: 0.686, blue: 0.537)

    /// Warm golden gradient top  #F2C94C
    static let appGoldTop = Color(red: 0.949, green: 0.788, blue: 0.298)

    /// Warm golden gradient bottom  #E07C12
    static let appGoldBottom = Color(red: 0.878, green: 0.486, blue: 0.071)
}
