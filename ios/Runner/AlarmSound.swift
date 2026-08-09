import AVFoundation
import AudioToolbox
import Flutter

/// osmWashabeの`TimerAlert`+`TimerCompletionSoundCatalog`+`IosSoundService`の移植。
/// タイマー完了音は2系統ある：
/// 1. 「カタログ音」— Appleのシステムサウンド18種（三連音・アンティシペート…）を
///    `AudioServicesPlaySystemSound`で再生する。storedValueは数値ID文字列
///    （例 "1307"）。
/// 2. 「着信音」— 端末の着信音ファイル（/System/Library/Ringtones,
///    /Library/Ringtones）をAVAudioPlayerで再生する。storedValueはファイルパス。
/// osmWashabeと同じく、どちらも再生完了を待たずに即座にresultを返す
/// （fire-and-forget）。
///
/// Flutter MethodChannel: com.osamushikubo.osm_gradus/alarm_sound
/// getSounds() -> [[String: String]]（storedValue, title）
/// play(storedValue: String)
/// stop()
final class AlarmSound: NSObject {
    private var player: AVAudioPlayer?

    /// osmWashabeの`TimerCompletionSoundCatalog.defaultNotificationItems`と同じ
    /// 18種・同じ日本語名。
    static let catalogSounds: [(id: UInt32, title: String)] = [
        (1307, "三連音"),
        (1320, "アンティシペート"),
        (1321, "ブルーム"),
        (1322, "カリプソ"),
        (1323, "チューチュー"),
        (1324, "ディセント"),
        (1325, "ファンファーレ"),
        (1326, "ラダー"),
        (1327, "メヌエット"),
        (1328, "ニュース"),
        (1329, "ノワール"),
        (1330, "シャーウッド"),
        (1331, "スペル"),
        (1332, "サスペンス"),
        (1333, "テレグラフ"),
        (1334, "ティプトゥ"),
        (1335, "タイプライター"),
        (1336, "アップデート"),
    ]

    // ガラガラ・スライド等の着信音ファイルを返す。
    private func listRingtoneFiles() -> [[String: String]] {
        let exts: Set<String> = ["m4r", "caf", "aif", "aiff"]
        var results: [[String: String]] = []
        for dir in ["/System/Library/Ringtones", "/Library/Ringtones"] {
            let url = URL(fileURLWithPath: dir)
            guard
                let files = try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil
                )
            else { continue }
            let sorted = files
                .filter { exts.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for file in sorted {
                results.append([
                    "storedValue": file.path,
                    "title": file.deletingPathExtension().lastPathComponent,
                ])
            }
        }
        return results
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSounds":
            var items = AlarmSound.catalogSounds.map {
                ["storedValue": "\($0.id)", "title": $0.title]
            }
            items += listRingtoneFiles()
            result(items)
        case "play":
            guard let value = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            play(storedValue: value, result: result)
        case "stop":
            stop()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func play(storedValue: String, result: @escaping FlutterResult) {
        stop()
        // カタログ音（システムサウンドID）: 再生完了を待たずに即返す。
        if let id = UInt32(storedValue) {
            AudioServicesPlaySystemSound(SystemSoundID(id))
            result(nil)
            return
        }
        // 着信音ファイル: こちらも再生完了を待たずに即返す。
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: storedValue))
            player = newPlayer
            newPlayer.play()
        } catch {
            // 再生失敗してもタイマー完了フローは止めない。
        }
        result(nil)
    }

    private func stop() {
        player?.stop()
        player = nil
    }
}
