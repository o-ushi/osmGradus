import 'dart:io';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/privacy_consent_service.dart';

/// 録音音声をOSの音声認識機能へ渡す前に、初回だけ明示同意を得る。
abstract final class SpeechProcessingConsentDialog {
  /// iOS/Androidで実装が異なる（iOSはApple Speech Recognitionのみ、
  /// AndroidはOSの音声認識→失敗時Voskフォールバック）ため、文言は
  /// プライバシー画面（[プライバシー_音声認識説明_iOS]/[_Android]）と同じ粒度で
  /// プラットフォームごとに分ける。
  static String get _bodyKey {
    if (Platform.isIOS) return '音声認識同意_本文_iOS';
    if (Platform.isAndroid) return '音声認識同意_本文_Android';
    return '音声認識同意_本文';
  }

  static Future<bool> ensure(BuildContext context, String languageCode) async {
    if (await PrivacyConsentService.hasSpeechProcessingConsent()) return true;
    if (!context.mounted) return false;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('音声認識同意_タイトル'.tr(languageCode)),
        content: SingleChildScrollView(
          child: Text(_bodyKey.tr(languageCode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '同意しない'.tr(languageCode),
              textAlign: TextAlign.center,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '同意して続ける'.tr(languageCode),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    await PrivacyConsentService.grantSpeechProcessingConsent();
    return true;
  }
}
