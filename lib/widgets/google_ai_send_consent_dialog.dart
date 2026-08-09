import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_strings.dart';
import '../views/settings/privacy_data_screen.dart';

/// Google検索（AIモード）へプロンプトを送る直前の同意ダイアログ。
/// レイヤーⅤ・ダッシュボードなど、送信元は分かれたまま、確認UIだけ共通化する。
abstract final class GoogleAiSendConsentDialog {
  /// [titleKey]・[bodyKey]は画面ごとの文言を差し替えるための翻訳キー。
  /// true = 同意して送信、false/ダイアログ却下 = キャンセル。
  static Future<bool> confirm(
    BuildContext context, {
    required String languageCode,
    String titleKey = 'Google送信確認_タイトル',
    String bodyKey = 'Google送信確認_本文',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titleKey.tr(languageCode)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bodyKey.tr(languageCode)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(PrivacyDataScreen.googlePrivacyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Google プライバシーポリシー'.tr(languageCode)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('キャンセル'.tr(languageCode), textAlign: TextAlign.center),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '同意してGoogleへ送信'.tr(languageCode),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
