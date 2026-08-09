import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/learner_answer_language.dart';

void main() {
  group('LearnerAnswerLanguageDetector', () {
    test('ひらがな・漢字中心の回答は日本語と判定する', () {
      expect(
        LearnerAnswerLanguageDetector.detect('物事を進めること'),
        LearnerAnswerLanguage.ja,
      );
    });

    test('ベトナム語の声調記号を含む回答はベトナム語と判定する', () {
      expect(
        LearnerAnswerLanguageDetector.detect('thúc đẩy'),
        LearnerAnswerLanguage.vi,
      );
    });

    test('声調記号のないラテン文字はベトナム語と判定する', () {
      expect(
        LearnerAnswerLanguageDetector.detect('promote'),
        LearnerAnswerLanguage.vi,
      );
      expect(
        LearnerAnswerLanguageDetector.detect('thuc day'),
        LearnerAnswerLanguage.vi,
      );
    });

    test('空文字は既定でベトナム語とする', () {
      expect(
        LearnerAnswerLanguageDetector.detect(''),
        LearnerAnswerLanguage.vi,
      );
    });
  });
}
