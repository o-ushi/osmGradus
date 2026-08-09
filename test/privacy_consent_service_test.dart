import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/services/privacy_consent_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('音声認識同意は初期状態ではfalseで、付与と撤回を永続化する', () async {
    expect(await PrivacyConsentService.hasSpeechProcessingConsent(), isFalse);

    await PrivacyConsentService.grantSpeechProcessingConsent();
    expect(await PrivacyConsentService.hasSpeechProcessingConsent(), isTrue);

    await PrivacyConsentService.revokeSpeechProcessingConsent();
    expect(await PrivacyConsentService.hasSpeechProcessingConsent(), isFalse);
  });
}
