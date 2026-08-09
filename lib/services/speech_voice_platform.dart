import 'dart:io';

import 'package:flutter/services.dart';

/// ネイティブiOS/Androidから日本語音声情報を取得する。
/// osmWashabeの`SpeechVoicePlatform`の移植。
abstract final class SpeechVoicePlatform {
  static const _channel = MethodChannel(
    'com.osamushikubo.osm_gradus/speech_voices',
  );

  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// プラットフォームTTSから日本語音声一覧を返す。
  static Future<List<Map<String, String>>> getJapaneseVoices() async {
    if (!isSupported) return [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getJapaneseVoices',
      );
      if (raw == null) return [];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (m) => m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 指定した性別で実際に使われる音声情報を返す（識別子直接試行ロジック使用）。
  /// genderは'男性の声' / '女性の声' / 'ランダム'。
  static Future<Map<String, String>?> getVoiceInfoForGender(
    String gender,
  ) async {
    if (!isSupported) return null;
    try {
      final nativeGender = _toNativeGender(gender);
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getVoiceInfoForGender',
        nativeGender,
      );
      if (raw == null) return null;
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (_) {
      return null;
    }
  }

  static String _toNativeGender(String rawGender) {
    switch (rawGender) {
      case '男性の声':
        return 'male';
      case 'ランダム':
        return 'random';
      default:
        return 'female';
    }
  }
}
