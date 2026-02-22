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

    // MARK: - Background music

    private var bgPlayer: AVAudioPlayer?
    private(set) var isMusicPlaying = false

    func startBackgroundMusic() {
        guard bgPlayer == nil || !(bgPlayer?.isPlaying ?? false) else { return }
        guard let url = Bundle.main.url(forResource: "bgmusic", withExtension: "mp3") else {
            print("[SoundPlayer] missing bgmusic.mp3")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.25
            player.prepareToPlay()
            player.play()
            bgPlayer = player
            isMusicPlaying = true
        } catch {
            print("[SoundPlayer] failed to load bgmusic: \(error)")
        }
    }

    func stopBackgroundMusic() {
        bgPlayer?.stop()
        isMusicPlaying = false
    }

    func toggleMusic() {
        if isMusicPlaying {
            stopBackgroundMusic()
        } else {
            startBackgroundMusic()
        }
    }
}
