import 'dart:io';

import 'package:flutter/services.dart';

/// iOS/Androidネイティブ TTS への直接ブリッジ。genderを渡すことで各OS側が
/// 性別に応じた日本語音声を直接選択する（flutter_ttsのsetVoiceには依存しない）。
/// osmWashabeの`NativeTtsPlatform`の移植。
abstract final class NativeTtsPlatform {
  static const _channel = MethodChannel('com.osamushikubo.osm_gradus/tts');

  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  static Future<bool> ensureReady() async {
    if (!isSupported) return true;
    try {
      return await _channel
              .invokeMethod<bool>('ensureReady')
              .timeout(const Duration(seconds: 8)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// genderに応じた音声でtextを読み上げる。
  /// 戻り値: true=完了, false=キャンセル/エラー, null=日本語TTS未インストール（スキップ）
  /// gender: '男性の声' | '女性の声' | 'ランダム'
  static Future<bool?> speak({
    required String text,
    required String gender,
    required double rate,
    double pitch = 1.0,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel
          .invokeMethod<bool?>('speak', {
            'text': text,
            'gender': _toNativeGender(gender),
            'rate': rate,
            'pitch': pitch,
          })
          .timeout(const Duration(seconds: 45), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<void> pause() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('pause');
    } catch (_) {}
  }

  static Future<void> resume() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('resume');
    } catch (_) {}
  }

  /// 端末の設定画面を開く。
  /// Android: 「テキスト読み上げの出力」設定画面
  /// iOS: このアプリの設定ページ（そこからアクセシビリティ→読み上げコンテンツ→声に進んでもらう）
  /// 日本語音声データが未インストールの端末で、案内から直接遷移させるために使う。
  static Future<bool> openSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } catch (_) {
      return false;
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
