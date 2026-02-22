import AVFoundation

// MARK: - Sound types

enum AppSound: String, CaseIterable {
    case tap     = "tap"
    case pop     = "pop"
    case wrong   = "wrong"
    case success = "success"
    case whoosh  = "whoosh"
    case reward  = "reward"
}

// MARK: - SoundPlayer

/// Lightweight singleton that preloads short mp3s and plays them instantly.
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [AppSound: AVAudioPlayer] = [:]

    private init() {
        for sound in AppSound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else {
                print("[SoundPlayer] missing: \(sound.rawValue).mp3")
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[sound] = player
            } catch {
                print("[SoundPlayer] failed to load \(sound.rawValue): \(error)")
            }
        }
    }

    func play(_ sound: AppSound) {
        guard let player = players[sound] else { return }
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }
}
