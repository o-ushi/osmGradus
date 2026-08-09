package com.osamushikubo.osm_gradus

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech as AndroidTextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

/**
 * osmWashabeのMainActivity.kt内TTS処理の移植。Android標準のTextToSpeechを直接ラップし、
 * flutter_ttsプラグインは使わない（iOS版TextToSpeech.swiftと対になるチャンネル構成）。
 *
 * Flutter MethodChannel: com.osamushikubo.osm_gradus/tts
 * ensureReady() -> Bool
 * speak(text:gender:rate:pitch:) -> Bool?（nullは日本語音声未インストール）
 * stop() / pause() / resume()
 */
class TextToSpeech(private val context: Context) {
    private var tts: AndroidTextToSpeech? = null
    private var ttsReady = false
    private var japaneseAvailable = true

    private var pendingResult: MethodChannel.Result? = null
    private var currentUtteranceId: String? = null
    private var activeCallbackEnabled = false

    private data class PendingSpeakRequest(
        val text: String,
        val gender: String,
        val rate: Float,
        val pitch: Float,
        val result: MethodChannel.Result,
    )
    private var pendingSpeak: PendingSpeakRequest? = null

    init {
        tts = AndroidTextToSpeech(context) { status ->
            if (status == AndroidTextToSpeech.SUCCESS) {
                ttsReady = true
                val langResult = tts?.setLanguage(Locale.JAPANESE)
                japaneseAvailable = langResult != AndroidTextToSpeech.LANG_MISSING_DATA &&
                    langResult != AndroidTextToSpeech.LANG_NOT_SUPPORTED
                // AudioAttributesを明示しないと、一部端末（Samsung One UIなど）でTTSの
                // 出力ストリームが無音のストリームにルーティングされ、コールバックは正常に
                // 発火するのに音だけ出ないことがある（osmWashabeで確認済みの不具合の移植元対応）。
                try {
                    tts?.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                } catch (_: Exception) {}
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}

                    override fun onDone(utteranceId: String?) {
                        finishIfCurrent(utteranceId, true)
                    }

                    @Deprecated("Deprecated in API 21")
                    override fun onError(utteranceId: String?) {
                        finishIfCurrent(utteranceId, false)
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        onError(utteranceId)
                    }
                })
                val pending = pendingSpeak
                pendingSpeak = null
                if (pending != null) {
                    startSpeech(pending.text, pending.gender, pending.rate, pending.pitch, pending.result)
                }
            } else {
                val pending = pendingSpeak
                pendingSpeak = null
                pending?.result?.success(false)
            }
        }
    }

    private fun finishIfCurrent(utteranceId: String?, success: Boolean) {
        if (utteranceId == currentUtteranceId && activeCallbackEnabled) {
            activeCallbackEnabled = false
            val r = pendingResult
            pendingResult = null
            currentUtteranceId = null
            Handler(Looper.getMainLooper()).post { r?.success(success) }
        }
    }

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureReady" -> {
                if (ttsReady) {
                    result.success(true)
                    return
                }
                val handler = Handler(Looper.getMainLooper())
                var attempts = 0
                val poll = object : Runnable {
                    override fun run() {
                        if (ttsReady) {
                            result.success(true)
                        } else if (attempts++ < 80) {
                            handler.postDelayed(this, 100)
                        } else {
                            result.success(false)
                        }
                    }
                }
                handler.post(poll)
            }
            "speak" -> {
                val args = call.arguments as? Map<*, *>
                val text = args?.get("text") as? String
                if (text == null) {
                    result.error("INVALID_ARGS", "text required", null)
                    return
                }
                val gender = args["gender"] as? String ?: "female"
                val rate = ((args["rate"] as? Double) ?: 0.5).toFloat()
                val pitch = ((args["pitch"] as? Double) ?: 1.0).toFloat()
                startSpeech(text, gender, rate, pitch, result)
            }
            "stop" -> {
                val queued = pendingSpeak
                pendingSpeak = null
                queued?.result?.success(false)
                val prev = pendingResult
                activeCallbackEnabled = false
                pendingResult = null
                currentUtteranceId = null
                tts?.stop()
                prev?.success(false)
                result.success(null)
            }
            "pause" -> {
                // Androidにはネイティブのpauseがないため、音声を止めるだけに留める。
                activeCallbackEnabled = false
                tts?.stop()
                result.success(null)
            }
            "resume" -> {
                result.success(null)
            }
            "openSettings" -> result.success(openSettings())
            else -> result.notImplemented()
        }
    }

    // 端末の「テキスト読み上げの出力」設定画面を開く（日本語音声データの追加・エンジン切替用）。
    private fun openSettings(): Boolean {
        val intents = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(AndroidTextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return true
            } catch (_: Exception) {}
        }
        return false
    }

    private fun startSpeech(
        text: String,
        gender: String,
        rate: Float,
        pitch: Float,
        result: MethodChannel.Result,
    ) {
        if (!ttsReady || tts == null) {
            pendingSpeak?.result?.success(false)
            pendingSpeak = PendingSpeakRequest(text, gender, rate, pitch, result)
            return
        }

        if (!japaneseAvailable) {
            result.success(null)
            return
        }

        val prev = pendingResult
        activeCallbackEnabled = false
        tts?.stop()
        prev?.success(false)

        applyVoiceForGender(gender)

        // iOS rate 0.5 = normal; Android rate 1.0 = normal → 2倍する。
        tts?.setSpeechRate((rate * 2.0f).coerceIn(0.5f, 2.0f))
        // Androidには男性の日本語音声がないため、低いピッチで疑似的に再現する。
        val effectivePitch = if (gender == "male") 0.65f else pitch.coerceIn(0.5f, 2.0f)
        tts?.setPitch(effectivePitch)

        val uid = UUID.randomUUID().toString()
        currentUtteranceId = uid
        activeCallbackEnabled = true
        pendingResult = result

        tts?.speak(text, AndroidTextToSpeech.QUEUE_FLUSH, null, uid)
    }

    private fun applyVoiceForGender(gender: String) {
        val engine = tts ?: return
        try {
            val voices = engine.voices
            if (voices == null) {
                engine.language = Locale.JAPANESE
                return
            }

            val jaLocal = voices.filter { it.locale.language == "ja" && !it.isNetworkConnectionRequired }
            val jaAll = voices.filter { it.locale.language == "ja" }
            val pool = jaLocal.ifEmpty { jaAll }

            if (pool.isEmpty()) {
                engine.language = Locale.JAPANESE
                return
            }

            val keywords = if (gender == "male") listOf("male", "man") else listOf("female", "woman")
            val matched = pool.firstOrNull { v -> keywords.any { v.name.lowercase().contains(it) } }
                ?: pool.first()

            try {
                engine.voice = matched
            } catch (_: Exception) {
                try { engine.language = Locale.JAPANESE } catch (_: Exception) {}
            }
        } catch (_: Exception) {
            try { engine.language = Locale.JAPANESE } catch (_: Exception) {}
        }
    }

    fun japaneseVoiceList(): List<Map<String, String>> {
        val engine = tts ?: return emptyList()
        return try {
            engine.voices
                ?.filter { it.locale.language == "ja" }
                ?.map { v ->
                    val lower = v.name.lowercase()
                    val g = when {
                        lower.contains("female") || lower.contains("woman") -> "female"
                        lower.contains("male") || lower.contains("man") -> "male"
                        else -> "unspecified"
                    }
                    mapOf(
                        "identifier" to v.name,
                        "name" to v.name,
                        "locale" to v.locale.toLanguageTag(),
                        "gender" to g,
                        "quality" to "default",
                    )
                } ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun voiceInfoForGender(gender: String): Map<String, String> {
        val engine = tts ?: return mapOf("name" to "Android TTS", "quality" to "default")
        return try {
            val voices = engine.voices?.filter { it.locale.language == "ja" }
            if (voices.isNullOrEmpty()) return mapOf("name" to "Android TTS", "quality" to "default")
            val keywords = if (gender == "male") listOf("male", "man") else listOf("female", "woman")
            val v = voices.firstOrNull { keywords.any { k -> it.name.lowercase().contains(k) } }
                ?: voices.first()
            mapOf("name" to v.name, "quality" to "default", "identifier" to v.name)
        } catch (_: Exception) {
            mapOf("name" to "Android TTS", "quality" to "default")
        }
    }

    fun dispose() {
        pendingSpeak?.result?.success(false)
        pendingSpeak = null
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
