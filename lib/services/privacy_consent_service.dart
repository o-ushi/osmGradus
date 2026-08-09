import 'package:shared_preferences/shared_preferences.dart';

/// 外部サービスを伴う音声認識への同意を、説明文の版と合わせて管理する。
abstract final class PrivacyConsentService {
  static const speechConsentVersion = 1;
  static const _speechConsentVersionKey =
      'osmGradus.privacy.speechConsentVersion';

  static Future<bool> hasSpeechProcessingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_speechConsentVersionKey) == speechConsentVersion;
  }

  static Future<void> grantSpeechProcessingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_speechConsentVersionKey, speechConsentVersion);
  }

  static Future<void> revokeSpeechProcessingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_speechConsentVersionKey);
  }
}
