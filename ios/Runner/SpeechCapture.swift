import AVFoundation
import Flutter
import Speech

/// 文字起こし進捗（0.0〜1.0）を Dart の EventChannel へ送る。
/// Android の Vosk 進捗チャンネル（`speech_capture_progress`）と同じ名前。
final class SpeechCaptureProgressStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = SpeechCaptureProgressStreamHandler()

    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(progress)
        }
    }
}

/// 発話フェーズの録音と、タイマー終了後のファイルベース文字起こしを担当する。
/// osmWashabeの`SpeechCaptureHandler`の移植（iOSにはAndroidのようなビープ問題は
/// ないため、Voskのようなオフラインフォールバックは不要）。
///
/// Flutter MethodChannel: com.osamushikubo.osm_gradus/speech_capture
/// startCapture(outputPath: String) → Bool
/// stopCapture()                   → String? (録音ファイルパス)
/// transcribeFile(path: String, locale: String?) → [[String: Any]] (単語ごとのタイムスタンプ付きセグメント)
///   localeはBCP-47タグ（例: "ja-JP"、"vi-VN"、"en-US"）。未指定時は"ja-JP"。
///   レイヤーⅣ/Ⅴ（学習者が常に日本語で話す）は省略され既定の日本語のまま、
///   レイヤーⅠの単語テスト（学習者がベトナム語/英語/日本語で口頭回答する）
///   だけ選択中の回答言語を明示的に渡してくる。
final class SpeechCapture: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingOutputPath: String?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCapture":
            guard let args = call.arguments as? [String: Any],
                  let path = args["outputPath"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            requestMicrophonePermission { [weak self] granted in
                guard let self else { return }
                guard granted else {
                    result(FlutterError(
                        code: "MIC_DENIED",
                        message: "Microphone permission denied",
                        details: nil
                    ))
                    return
                }
                do {
                    try self.startRecording(to: path)
                    result(true)
                } catch {
                    result(FlutterError(code: "START_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }

        case "stopCapture":
            result(stopRecording())

        case "transcribeFile":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            let locale = args["locale"] as? String ?? "ja-JP"
            transcribe(path: path, locale: locale, flutterResult: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Private

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        @unknown default:
            completion(false)
        }
    }

    private func startRecording(to path: String) throws {
        stopRecording() // 前回の録音が残っていれば停止

        // `.record`単体だと録音中は一切の再生（TTS「それでは、答えてください」や
        // タイマー音）がルーティングされず完全に無音になる（実機で確認済み）。
        // 録音しながら短い音声を鳴らせるよう`.playAndRecord`にし、
        // `.defaultToSpeaker`でイヤピースではなくスピーカーへ再生させる。
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord, mode: .default,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        if session.isInputGainSettable {
            try? session.setInputGain(1.0)
        }

        let url = URL(fileURLWithPath: path)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000,
        ]
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        recordingOutputPath = path
    }

    @discardableResult
    private func stopRecording() -> String? {
        audioRecorder?.stop()
        audioRecorder = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
        let path = recordingOutputPath
        recordingOutputPath = nil
        return path
    }

    /// 単語ごとのタイムスタンプ付きセグメントを返す。
    /// 戻り値: [[String: Any]] — 各要素は {"text": String, "timestamp": Double, "duration": Double}
    private func transcribe(path: String, locale: String, flutterResult: @escaping FlutterResult) {
        guard FileManager.default.fileExists(atPath: path) else {
            flutterResult(FlutterError(code: "NO_FILE", message: "Recording file missing", details: nil))
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    flutterResult(FlutterError(
                        code: "SPEECH_DENIED",
                        message: "Speech recognition permission denied",
                        details: nil
                    ))
                    return
                }
                self.performTranscription(path: path, locale: locale, flutterResult: flutterResult)
            }
        }
    }

    private func performTranscription(path: String, locale: String, flutterResult: @escaping FlutterResult) {
        // ロケールごとに毎回インスタンス化する（学習者が問題ごとに回答言語を
        // 切り替えられるため、固定のrecognizerを使い回さない）。
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.isAvailable
        else {
            flutterResult(FlutterError(
                code: "SPEECH_UNAVAILABLE",
                message: "Speech recognizer unavailable",
                details: nil
            ))
            return
        }

        let url = URL(fileURLWithPath: path)
        let audioDuration = Self.audioDurationSeconds(at: url)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        var responded = false
        var latestSegments: [[String: Any]] = []
        SpeechCaptureProgressStreamHandler.shared.send(0)

        func finish(with segments: [[String: Any]]) {
            guard !responded else { return }
            responded = true
            SpeechCaptureProgressStreamHandler.shared.send(1.0)
            flutterResult(segments)
        }

        func mapSegments(_ transcription: SFTranscription) -> [[String: Any]] {
            transcription.segments.map { seg in
                ["text": seg.substring, "timestamp": seg.timestamp, "duration": seg.duration]
            }
        }

        let task = recognizer.recognitionTask(with: request) { recognitionResult, error in
            if let recognitionResult = recognitionResult {
                latestSegments = mapSegments(recognitionResult.bestTranscription)
                let progress = Self.estimateProgress(
                    segments: latestSegments,
                    duration: audioDuration,
                    isFinal: recognitionResult.isFinal
                )
                SpeechCaptureProgressStreamHandler.shared.send(progress)
                if recognitionResult.isFinal {
                    finish(with: latestSegments)
                }
            }

            if let error = error {
                // 途中結果があればそれを返す（無音判定エラーでも拾えるようにする）
                finish(with: latestSegments)
                if latestSegments.isEmpty {
                    NSLog("SpeechCapture transcribe error: \(error.localizedDescription)")
                }
            }
        }

        // isFinalが来ないケースの保険（シミュレーター等）
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            guard !responded else { return }
            task.cancel()
            finish(with: latestSegments)
        }
    }

    private static func audioDurationSeconds(at url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite, seconds > 0 {
            return seconds
        }
        return 1.0
    }

    /// 部分認識の最終セグメント位置 / 音声長で進捗を近似する。
    private static func estimateProgress(
        segments: [[String: Any]],
        duration: Double,
        isFinal: Bool
    ) -> Double {
        if isFinal { return 1.0 }
        guard duration > 0, let last = segments.last else { return 0.05 }
        let timestamp = last["timestamp"] as? Double ?? 0
        let segmentDuration = last["duration"] as? Double ?? 0
        let processed = timestamp + segmentDuration
        return min(0.95, max(0.05, processed / duration))
    }
}
