import SwiftUI

// MARK: - Word Letter

struct WordLetter: Identifiable, Equatable {
    let id: UUID
    let character: Character
    let isBlank: Bool
}

// MARK: - Puzzle State

enum PuzzleState: Equatable {
    case idle
    case correct
    case wrong
}

// MARK: - Word Puzzle

struct WordPuzzle: Identifiable, Equatable {
    let id: UUID
    let word: String
    let modelName: String
    let tileColor: Color
    let letters: [WordLetter]
    let blankIndex: Int
    let missingLetter: Character

    static func make(word: String, modelName: String, color: Color, blankAt: Int = 1) -> WordPuzzle {
        let chars = Array(word.uppercased())
        let blankIdx = min(blankAt, chars.count - 1)
        let letters = chars.enumerated().map { i, c in
            WordLetter(id: UUID(), character: c, isBlank: i == blankIdx)
        }
        return WordPuzzle(
            id: UUID(),
            word: word.uppercased(),
            modelName: modelName,
            tileColor: color,
            letters: letters,
            blankIndex: blankIdx,
            missingLetter: chars[blankIdx]
        )
    }

    static let all: [WordPuzzle] = [
        .make(word: "BAG", modelName: "bag", color: Color(red: 0.95, green: 0.55, blue: 0.20)),
        .make(word: "BAT", modelName: "bat", color: Color(red: 0.55, green: 0.45, blue: 0.75)),
        .make(word: "CAT", modelName: "cat", color: Color(red: 1.0,  green: 0.45, blue: 0.45)),
        // .make(word: "HAT", modelName: "hat", color: Color(red: 0.90, green: 0.38, blue: 0.72)),
        .make(word: "HEN", modelName: "hen", color: Color(red: 0.95, green: 0.65, blue: 0.15)),
        .make(word: "KEY", modelName: "key", color: Color(red: 0.38, green: 0.72, blue: 0.98)),
        // .make(word: "PIG", modelName: "pig", color: Color(red: 1.0,  green: 0.60, blue: 0.70)),
        .make(word: "SUN", modelName: "sun", color: Color(red: 1.0,  green: 0.78, blue: 0.10)),
    ]
}
