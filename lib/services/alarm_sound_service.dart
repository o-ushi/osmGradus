import 'dart:io';

import 'package:flutter/services.dart';

/// タイマー完了音1件分。iOSは「カタログ音」（Appleのシステムサウンド、
/// storedValueが数値ID文字列）と「着信音」（ファイルパス）の2種類、
/// Androidは通知音一覧（storedValueがURI）。
class AlarmSoundOption {
  const AlarmSoundOption({required this.storedValue, required this.title});

  final String storedValue;
  final String title;
}

/// タイマー完了時に鳴らすアラーム音の一覧取得・再生・停止。
/// osmWashabeの`TimerAlert`/`AndroidRingtoneService`/`IosSoundService`/
/// `TimerCompletionSoundCatalog`の移植。osmWashabeと同じく、[play]は
/// 再生完了を待たずに返る（fire-and-forget）。
abstract final class AlarmSoundService {
  static const _channel = MethodChannel(
    'com.osamushikubo.osm_gradus/alarm_sound',
  );

  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  static Future<List<AlarmSoundOption>> getSounds() async {
    if (!isSupported) return [];
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('getSounds')
          .timeout(const Duration(seconds: 5));
      if (raw == null) return [];
      return raw
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return AlarmSoundOption(
              storedValue: map['storedValue'] as String? ?? '',
              title: map['title'] as String? ?? '',
            );
          })
          .where((option) => option.storedValue.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// osmWashabeと同じくfire-and-forget（ネイティブ側は再生開始したら
  /// すぐにresultを返す）。呼び出し自体が固まらないよう短いタイムアウトだけ付ける。
  static Future<void> play(String storedValue) async {
    if (!isSupported || storedValue.isEmpty) return;
    try {
      await _channel
          .invokeMethod<void>('play', storedValue)
          .timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
