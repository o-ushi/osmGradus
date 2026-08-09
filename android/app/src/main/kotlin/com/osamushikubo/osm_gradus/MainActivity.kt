package com.osamushikubo.osm_gradus

import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// audio_serviceがFlutterエンジンをフォアグラウンドサービスと共有できるよう、
// FlutterActivityではなくAudioServiceActivityを継承する。
class MainActivity : AudioServiceActivity() {

    private var speechCapture: SpeechCapture? = null
    private var speechProgressSink: EventChannel.EventSink? = null
    private var textToSpeech: TextToSpeech? = null
    private var alarmSound: AlarmSound? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        speechCapture = SpeechCapture(
            this,
            Handler(Looper.getMainLooper()),
        ) { progress -> speechProgressSink?.success(progress) }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechCapture.CHANNEL,
        ).setMethodCallHandler { call, result ->
            speechCapture?.handle(call, result) ?: result.notImplemented()
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechCapture.PROGRESS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                speechProgressSink = events
            }

            override fun onCancel(arguments: Any?) {
                speechProgressSink = null
            }
        })

        val tts = TextToSpeech(applicationContext)
        textToSpeech = tts

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.osamushikubo.osm_gradus/tts",
        ).setMethodCallHandler { call, result ->
            tts.handle(call, result)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.osamushikubo.osm_gradus/speech_voices",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getJapaneseVoices" -> result.success(tts.japaneseVoiceList())
                "getVoiceInfoForGender" -> {
                    val gender = call.arguments as? String ?: "female"
                    result.success(tts.voiceInfoForGender(gender))
                }
                else -> result.notImplemented()
            }
        }

        val alarm = AlarmSound(applicationContext)
        alarmSound = alarm

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.osamushikubo.osm_gradus/alarm_sound",
        ).setMethodCallHandler { call, result ->
            alarm.handle(call, result)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        speechCapture?.onRequestPermissionsResult(requestCode, grantResults)
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        speechCapture?.dispose()
        speechCapture = null
        speechProgressSink = null
        textToSpeech?.dispose()
        textToSpeech = null
        alarmSound?.stop()
        alarmSound = null
        super.onDestroy()
    }
}
