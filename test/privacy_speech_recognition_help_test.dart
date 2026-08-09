import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/localization/gradus_l10n.dart';

/// プライバシー画面の音声認識説明は、iOS向けにVoskという単語を出さない
/// （App Store審査対策）。Platformをモックせずに検証できるよう、
/// プラットフォーム別キーの文言そのものをja/en/viすべてで確認する。
void main() {
  test('iOS向け「プライバシー_音声認識説明_iOS」はja/en/viいずれもVoskに言及しない', () {
    for (final lang in ['ja', 'en', 'vi']) {
      final text = GradusL10n.data[lang]!['プライバシー_音声認識説明_iOS']!;
      expect(
        text.toLowerCase().contains('vosk'),
        isFalse,
        reason: '$lang: $text',
      );
    }
  });

  test('Android向け「プライバシー_音声認識説明_Android」はja/en/viいずれもVoskに言及する', () {
    for (final lang in ['ja', 'en', 'vi']) {
      final text = GradusL10n.data[lang]!['プライバシー_音声認識説明_Android']!;
      expect(
        text.toLowerCase().contains('vosk'),
        isTrue,
        reason: '$lang: $text',
      );
    }
  });
}
