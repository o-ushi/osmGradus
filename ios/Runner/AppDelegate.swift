import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iCloudSyncChannel: ICloudSyncChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // 一度 SwiftUI.AppSceneDelegate で保存されたシーンは、Info.plist の
    // SceneDelegate を読まずに復元される。畳んだ外側画面はプロセスが生きたまま黒くなる。
    // 設定名は毎回逆引き DNS にする。残った "flutter" を状態保存の種別に使うと落ちる。
    let configuration = UISceneConfiguration(
      name: SceneConfiguration.name,
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    configuration.storyboard = UIStoryboard(name: "Main", bundle: nil)
    return configuration
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudSyncChannel") {
      iCloudSyncChannel = ICloudSyncChannel(messenger: registrar.messenger())
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpeechCapture") {
      let speechCapture = SpeechCapture()
      let speechChannel = FlutterMethodChannel(
        name: "com.osamushikubo.osm_gradus/speech_capture",
        binaryMessenger: registrar.messenger()
      )
      speechChannel.setMethodCallHandler { call, result in
        speechCapture.handle(call, result: result)
      }
      let progressChannel = FlutterEventChannel(
        name: "com.osamushikubo.osm_gradus/speech_capture_progress",
        binaryMessenger: registrar.messenger()
      )
      progressChannel.setStreamHandler(SpeechCaptureProgressStreamHandler.shared)
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TextToSpeech") {
      let tts = TextToSpeech()
      let ttsChannel = FlutterMethodChannel(
        name: "com.osamushikubo.osm_gradus/tts",
        binaryMessenger: registrar.messenger()
      )
      ttsChannel.setMethodCallHandler { call, result in
        tts.handle(call, result: result)
      }

      let voicesChannel = FlutterMethodChannel(
        name: "com.osamushikubo.osm_gradus/speech_voices",
        binaryMessenger: registrar.messenger()
      )
      voicesChannel.setMethodCallHandler { call, result in
        if call.method == "getJapaneseVoices" {
          let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .map { v -> [String: String] in
              var d: [String: String] = [:]
              d["identifier"] = v.identifier
              d["name"] = v.name
              d["locale"] = v.language
              switch v.gender {
              case .male: d["gender"] = "male"
              case .female: d["gender"] = "female"
              default: d["gender"] = "unspecified"
              }
              switch v.quality {
              case .premium: d["quality"] = "premium"
              case .enhanced: d["quality"] = "enhanced"
              default: d["quality"] = "default"
              }
              return d
            }
          result(voices)
        } else if call.method == "getVoiceInfoForGender",
          let gender = call.arguments as? String
        {
          result(TextToSpeech.voiceInfo(for: gender))
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmSound") {
      let alarmSound = AlarmSound()
      let alarmChannel = FlutterMethodChannel(
        name: "com.osamushikubo.osm_gradus/alarm_sound",
        binaryMessenger: registrar.messenger()
      )
      alarmChannel.setMethodCallHandler { call, result in
        alarmSound.handle(call, result: result)
      }
    }
  }
}

/// iCloud の KVS（学習データと設定の同期データ）を Dart から使う出入り口
/// （osmNichinichi の ICloudSyncChannel から写真の部分を除いたもの）。
/// 同期の判断（変わったか・マージ）は Dart の CloudSyncService で行う。
final class ICloudSyncChannel: NSObject {
  static let channelName = "com.osamushikubo.osm_gradus/icloud"
  static let dataKey = "osmGradus-sync-v1"
  static let timestampKey = "osmGradus-sync-v1-ts"
  /// KVS の 1 値の上限（Dart 側でも確かめる）。
  static let maxBytes = 1_000_000

  private let channel: FlutterMethodChannel
  private let kvStore = NSUbiquitousKeyValueStore.default
  private var observer: NSObjectProtocol?

  /// iCloud からの初回ダウンロードが終わったか。終わる前はローカルの KVS が空でも、
  /// クラウドに既存のデータがあることがある（新規インストールがそれを上書きしないため）。
  private var initialSyncFinished = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(FileManager.default.ubiquityIdentityToken != nil)

    case "startObserving":
      if observer == nil {
        observer = NotificationCenter.default.addObserver(
          forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
          object: kvStore,
          queue: .main
        ) { [weak self] notification in
          guard let self else { return }
          let reason = (notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber)?.intValue
          if reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            self.initialSyncFinished = true
          } else if reason == NSUbiquitousKeyValueStoreAccountChange {
            // 別の iCloud アカウントに替わった。前の空読みで送らない。
            self.initialSyncFinished = false
          }
          let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
          let initial = reason == NSUbiquitousKeyValueStoreInitialSyncChange
          // 初回同期は、クラウドが空でも通知する（空だと分かってから送るため）。
          guard initial || keys.contains(Self.dataKey) else { return }
          self.channel.invokeMethod("externalChange", arguments: nil)
        }
      }
      kvStore.synchronize()
      // すでに値があるなら、初回ダウンロードは過去に終わっている。
      if kvStore.object(forKey: Self.dataKey) != nil {
        initialSyncFinished = true
      }
      result(nil)

    case "hasFinishedInitialSync":
      result(initialSyncFinished)

    case "read":
      kvStore.synchronize()
      result([
        "data": kvStore.string(forKey: Self.dataKey) as Any,
        "timestamp": kvStore.double(forKey: Self.timestampKey),
      ])

    case "write":
      guard let args = call.arguments as? [String: Any],
            let data = args["data"] as? String,
            let timestamp = args["timestamp"] as? Double else {
        result(FlutterError(code: "badArgs", message: "data / timestamp が必要", details: nil))
        return
      }
      let bytes = data.utf8.count
      guard bytes < Self.maxBytes else {
        result(FlutterError(code: "tooLarge", message: "\(bytes) bytes", details: bytes))
        return
      }
      kvStore.set(data, forKey: Self.dataKey)
      kvStore.set(timestamp, forKey: Self.timestampKey)
      kvStore.synchronize()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
