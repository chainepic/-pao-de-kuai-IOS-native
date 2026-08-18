import AVFoundation

enum SpeechService {
    private static var synthesizer: AVSpeechSynthesizer?
    private static var queuePlayer: AVQueuePlayer?
    private static let enabledKey = "paodekuai.native.speech.enabled"
    private static var isAudioSessionConfigured = false
    private static var resolvedAudioURLs: [String: URL] = [:]
    private static var missingAudioKeys: Set<String> = []
    private static let supportedAudioExtensions = ["m4a", "caf", "wav", "mp3", "aac"]

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            queuePlayer?.pause()
            queuePlayer?.removeAllItems()
            synthesizer?.stopSpeaking(at: .immediate)
        }
    }

    private static func configureAudioSessionIfNeeded() {
        #if os(iOS)
        guard !isAudioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
            isAudioSessionConfigured = true
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }

    static func speak(_ text: String) {
        play(VoiceLine(clips: [], fallbackText: text, language: L10n.currentLanguage()))
    }

    static func play(_ line: VoiceLine) {
        guard isEnabled else { return }
        guard !line.isEmpty else { return }

        DispatchQueue.main.async {
            configureAudioSessionIfNeeded()
            stopCurrentSpeech()

            if let urls = audioURLs(for: line.clips, language: line.language) {
                playLocalAudio(urls)
                return
            }

            speakFallback(line.fallbackText, language: line.language)
        }
    }

    private static func stopCurrentSpeech() {
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        synthesizer?.stopSpeaking(at: .immediate)
    }

    private static func playLocalAudio(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let items = urls.map { AVPlayerItem(url: $0) }
        let player = AVQueuePlayer(items: items)
        queuePlayer = player
        player.play()
    }

    private static func speakFallback(_ text: String, language: AppLanguage) {
        guard !text.isEmpty else { return }
        if synthesizer == nil {
            synthesizer = AVSpeechSynthesizer()
        }

        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: language.speechCode) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer?.speak(utterance)
    }

    private static func audioURLs(for clips: [VoiceClip], language: AppLanguage) -> [URL]? {
        guard !clips.isEmpty else { return nil }
        var urls: [URL] = []
        urls.reserveCapacity(clips.count)
        for clip in clips {
            guard let url = audioURL(for: clip, language: language) else {
                return nil
            }
            urls.append(url)
        }
        return urls
    }

    private static func audioURL(for clip: VoiceClip, language: AppLanguage) -> URL? {
        let cacheKey = "\(language.rawValue)/\(clip.rawValue)"
        if let cached = resolvedAudioURLs[cacheKey] {
            return cached
        }
        if missingAudioKeys.contains(cacheKey) {
            return nil
        }

        for ext in supportedAudioExtensions {
            if let url = Bundle.main.url(forResource: clip.rawValue, withExtension: ext) {
                resolvedAudioURLs[cacheKey] = url
                return url
            }

            for resourceFolder in resourceFolders(for: language) {
                if let url = Bundle.main.url(forResource: clip.rawValue, withExtension: ext, subdirectory: resourceFolder) {
                    resolvedAudioURLs[cacheKey] = url
                    return url
                }

                let directURL = Bundle.main.bundleURL
                    .appendingPathComponent(resourceFolder, isDirectory: true)
                    .appendingPathComponent("\(clip.rawValue).\(ext)")
                if FileManager.default.fileExists(atPath: directURL.path) {
                    resolvedAudioURLs[cacheKey] = directURL
                    return directURL
                }
            }
        }

        missingAudioKeys.insert(cacheKey)
        return nil
    }

    private static func resourceFolders(for language: AppLanguage) -> [String] {
        [
            "Voice/\(language.rawValue)",
            "Voice.bundle/\(language.rawValue)",
            "Resources/Voice/\(language.rawValue)"
        ]
    }
}
