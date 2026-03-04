import AVFoundation

enum SpeechService {
    private static var synthesizer: AVSpeechSynthesizer?
    private static let enabledKey = "paodekuai.native.speech.enabled"
    private static var isAudioSessionConfigured = false

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            synthesizer?.stopSpeaking(at: .immediate)
        }
    }

    private static func configureAudioSessionIfNeeded() {
        guard !isAudioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
            isAudioSessionConfigured = true
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    static func speak(_ text: String) {
        guard isEnabled else { return }
        guard !text.isEmpty else { return }
        
        configureAudioSessionIfNeeded()
        
        if synthesizer == nil {
            synthesizer = AVSpeechSynthesizer()
        }
        
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: L10n.currentLanguage().speechCode) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        // Ensure we speak on the main thread
        DispatchQueue.main.async {
            synthesizer?.speak(utterance)
        }
    }
}
