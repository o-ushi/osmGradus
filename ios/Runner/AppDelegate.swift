import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

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
