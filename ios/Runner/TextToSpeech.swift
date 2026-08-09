import AVFoundation
import Flutter
import UIKit

/// osmWashabeの`NativeTtsHandler`の移植（AppDelegate.swift内の非公開クラスだったものを
/// 独立ファイル化）。AVSpeechSynthesizerを直接ラップし、flutter_ttsプラグインは使わない。
///
/// Flutter MethodChannel: com.osamushikubo.osm_gradus/tts
/// speak(text:gender:rate:pitch:) -> Bool
/// stop() / pause() / resume()
///
/// FlutterMethodChannelのハンドラクロージャが`@Sendable`になったことで、
/// それに捕捉されるこのクラス自体もSendable適合を要求されるが、
/// `AVSpeechSynthesizer`はSendable非対応の型のため自動導出できず警告になる。
/// 実際にはAppDelegateで1つだけ生成され、Flutterのメソッドチャンネル
/// ハンドラ（常にメインスレッドで呼ばれる）経由でしかアクセスされないため、
/// スレッド安全性は担保できている前提で`@unchecked Sendable`にする。
final class TextToSpeech: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingResult: FlutterResult?
    // 発話インスタンスを追跡し、古いdidCancel/didFinishが新しいpendingResultを
    // 誤って解決しないようにする。
    private var pendingUtterance: AVSpeechUtterance?

    private static let maleIdentifiers: [String] = [
        "com.apple.voice.premium.ja-JP.Otoya",
        "com.apple.voice.enhanced.ja-JP.Otoya",
        "com.apple.voice.compact.ja-JP.Otoya",
        "com.apple.ttsbundle.Otoya-premium",
        "com.apple.ttsbundle.Otoya-compact",
    ]

    private static let femaleIdentifiers: [String] = [
        "com.apple.voice.premium.ja-JP.Kyoko",
        "com.apple.voice.enhanced.ja-JP.Kyoko",
        "com.apple.voice.compact.ja-JP.Kyoko",
        "com.apple.ttsbundle.Kyoko-premium",
        "com.apple.ttsbundle.Kyoko-compact",
    ]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // 性別に応じた音声を選択: speechVoices()に頼らず識別子を直接試行する。
    static func voiceForGender(_ gender: String) -> AVSpeechSynthesisVoice? {
        let candidates: [String]
        switch gender {
        case "male":
            candidates = maleIdentifiers
        default: // female/random — 男女をランダムに優先して選択
            candidates = gender == "random"
                ? (Bool.random() ? maleIdentifiers + femaleIdentifiers : femaleIdentifiers + maleIdentifiers)
                : femaleIdentifiers
        }

        for id in candidates {
            if let voice = AVSpeechSynthesisVoice(identifier: id), voice.language.hasPrefix("ja") {
                return voice
            }
        }

        // speechVoices()から性別でフィルタ（Siriボイスは除外する）。
        // システム言語が日本語以外（例: ベトナム語）だと、上の既知識別子が端末に
        // インストールされておらずnilになるケースがある。その場合でも
        // 性別違いの日本語ボイスがあればそちらを優先する（無音/誤言語よりまし）。
        let isMale: Bool
        if gender == "male" {
            isMale = true
        } else if gender == "random" {
            isMale = Bool.random()
        } else {
            isMale = false
        }
        let target: AVSpeechSynthesisVoiceGender = isMale ? .male : .female
        let japaneseVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") && !$0.identifier.contains("siri") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        if let genderMatch = japaneseVoices.first(where: { $0.gender == target }) {
            return genderMatch
        }
        if let anyJapanese = japaneseVoices.first {
            return anyJapanese
        }

        // 最終フォールバック。AVSpeechSynthesisVoice(language:)は日本語音声データが
        // 端末に一切無い場合、別言語（システム言語）のボイスを返すことがあるため、
        // 返り値が本当に日本語かどうかを必ず検証する。
        if let fallback = AVSpeechSynthesisVoice(language: "ja-JP"), fallback.language.hasPrefix("ja") {
            return fallback
        }

        return nil
    }

    // 選択された音声のメタ情報を返す（設定画面の「使用中の声」表示用）。
    static func voiceInfo(for gender: String) -> [String: String] {
        guard let voice = voiceForGender(gender) else {
            return ["name": "Kyoko", "quality": "default"]
        }
        var quality = "default"
        switch voice.quality {
        case .premium: quality = "premium"
        case .enhanced: quality = "enhanced"
        default: quality = "default"
        }
        return ["name": voice.name, "quality": quality, "identifier": voice.identifier]
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "speak":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            let gender = args["gender"] as? String ?? "female"
            let rate = Float((args["rate"] as? Double) ?? 0.5)
            let pitch = Float((args["pitch"] as? Double) ?? 1.0)
            doSpeak(text: text, gender: gender, rate: rate, pitch: pitch, result: result)

        case "stop":
            let r = pendingResult
            pendingResult = nil
            pendingUtterance = nil
            synthesizer.stopSpeaking(at: .immediate)
            r?(false)
            result(nil)

        case "pause":
            synthesizer.pauseSpeaking(at: .word)
            result(nil)

        case "resume":
            synthesizer.continueSpeaking()
            result(nil)

        case "openSettings":
            result(TextToSpeech.openIosSettings())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // このアプリの設定ページを開く（そこから アクセシビリティ→読み上げコンテンツ→声 に
    // 進んでもらう。iOSには特定の設定画面に直接ディープリンクする公開APIが無いため）。
    static func openIosSettings() -> Bool {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        return true
    }

    private func doSpeak(
        text: String, gender: String, rate: Float, pitch: Float,
        result: @escaping FlutterResult
    ) {
        let prev = pendingResult
        pendingResult = nil
        pendingUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            prev?(false)
        }

        // 性別に応じた音声を直接設定する。日本語音声が端末上で1つも見つからない
        // 場合はAndroidの「TTS未インストール」パスと同様にnilを返し、
        // 誤言語での発話を避ける。
        guard let voice = TextToSpeech.voiceForGender(gender) else {
            result(nil)
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = voice

        pendingResult = result
        pendingUtterance = utterance
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        guard utterance === pendingUtterance else { return }
        let r = pendingResult
        pendingResult = nil
        pendingUtterance = nil
        r?(true)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        guard utterance === pendingUtterance else { return }
        let r = pendingResult
        pendingResult = nil
        pendingUtterance = nil
        r?(false)
    }
}
