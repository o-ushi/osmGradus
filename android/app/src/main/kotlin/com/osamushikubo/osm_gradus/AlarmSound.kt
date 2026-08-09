package com.osamushikubo.osm_gradus

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.plugin.common.MethodChannel

/**
 * osmWashabeの`AndroidRingtoneService`の移植。
 * タイマー完了時に鳴らすアラーム音を、端末の通知音一覧から選べるようにする。
 * osmWashabeと同じく、再生完了を待たずに即座にresultを返す（fire-and-forget）。
 *
 * Flutter MethodChannel: com.osamushikubo.osm_gradus/alarm_sound
 * getSounds() -> [[String: String]]（storedValue = uri, title）
 * play(uri: String)
 * stop()
 */
class AlarmSound(private val context: Context) {
    private var player: MediaPlayer? = null

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSounds" -> result.success(getRingtones())
            "play" -> {
                val uri = call.arguments as? String
                if (uri == null) {
                    result.success(null)
                    return
                }
                play(uri)
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getRingtones(): List<Map<String, String>> {
        val list = mutableListOf<Map<String, String>>()
        try {
            val mgr = RingtoneManager(context)
            mgr.setType(RingtoneManager.TYPE_NOTIFICATION)
            val cursor = mgr.cursor
            while (cursor.moveToNext()) {
                val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                val uri = mgr.getRingtoneUri(cursor.position).toString()
                list.add(mapOf("storedValue" to uri, "title" to title))
            }
            cursor.close()
        } catch (_: Exception) {
        }
        return list
    }

    private fun play(uriString: String) {
        stop()
        try {
            val mp = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(context, Uri.parse(uriString))
                setVolume(1.0f, 1.0f)
                prepare()
                setOnCompletionListener { mp2 ->
                    mp2.release()
                    if (player === mp2) player = null
                }
                start()
            }
            player = mp
        } catch (e: Exception) {
            player = null
        }
    }

    fun stop() {
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }
}
