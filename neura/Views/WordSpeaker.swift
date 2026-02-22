import AVFoundation
import Combine
@MainActor
final class WordSpeaker: NSObject, ObservableObject {

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio,
                                 options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
        #endif
    }

    func speakLetter(_ letter: Character) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: String(letter).lowercased())
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.38
        utterance.pitchMultiplier = 1.35
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func spellThenSpeak(_ word: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let spelled = word.lowercased().map { String($0) }.joined(separator: "... ")
        let fullText = "\(spelled)... \(word.lowercased())"
        let utterance = AVSpeechUtterance(string: fullText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.35
        utterance.pitchMultiplier = 1.3
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}
