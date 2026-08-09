import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/pronunciation_ai_prompt_template.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/pronunciation_practice_session.dart';

List<PronunciationPracticeQuestion> _questions() {
  const exercise = PronunciationExercise(
    id: 'ex1',
    category: PronunciationCategory.tsu,
    sentence: '机の上にあります。',
    reading: 'つくえのうえにあります',
    targetExpressions: ['机'],
    vietnameseHint: 'Trên bàn.',
    evaluationPoint: 'つ',
    source: PronunciationExerciseSource.builtIn,
  );
  return [
    PronunciationPracticeQuestion(
      exercise: exercise,
      status: PronunciationQuestionStatus.completed,
      sttResult: 'つくえのうえにあります',
    ),
  ];
}

void main() {
  group('PronunciationAiPromptTemplate.evaluationPrompt', () {
    test('JSONスキーマはfeedback/summaryを1つずつ要求する（feedbackJa/feedbackVi併記は要求しない）', () {
      for (final lang in ['ja', 'en', 'vi']) {
        final prompt = PronunciationAiPromptTemplate.evaluationPrompt(
          questions: _questions(),
          lang: lang,
        );
        expect(prompt, contains('"feedback"'));
        expect(prompt, contains('"summary"'));
        expect(prompt, isNot(contains('feedbackJa')));
        expect(prompt, isNot(contains('feedbackVi')));
        expect(prompt, isNot(contains('summaryJa')));
        expect(prompt, isNot(contains('summaryVi')));
      }
    });

    test('lang=enの指示文はfeedback/summaryを英語で書くよう求める', () {
      final prompt = PronunciationAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'en',
      );
      expect(prompt, contains('Write feedback and summary in English.'));
    });

    test('lang=viの指示文はfeedback/summaryをベトナム語で書くよう求める', () {
      final prompt = PronunciationAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'vi',
      );
      expect(prompt, contains('Viết feedback và summary bằng tiếng Việt.'));
    });

    test('lang=jaの指示文はfeedback/summaryを日本語で書くよう求める', () {
      final prompt = PronunciationAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'ja',
      );
      expect(prompt, contains('feedbackとsummaryは日本語で書いてください。'));
    });
  });

  group('PronunciationAiPromptTemplate.evaluationSearchUrl', () {
    // 実際にChrome AIの解析が不安定になっていた原因（回帰テスト）：
    // 検索クエリの先頭に常に「日本語で」が固定で付いており、lang=en/viの
    // ときプロンプト本文の指示（Write feedback in English 等）と矛盾して
    // JSON形式が崩れやすくなっていた。lang別に正しい接頭辞が付くことを確認する。
    test('lang=jaの検索クエリは「日本語で」で始まる', () {
      final url = PronunciationAiPromptTemplate.evaluationSearchUrl(
        questions: _questions(),
        lang: 'ja',
      );
      final query = url.queryParameters['q']!;
      expect(query, startsWith('日本語で'));
    });

    test('lang=enの検索クエリは英語の指示で始まり、「日本語で」を含まない', () {
      final url = PronunciationAiPromptTemplate.evaluationSearchUrl(
        questions: _questions(),
        lang: 'en',
      );
      final query = url.queryParameters['q']!;
      expect(query, startsWith('In English, '));
      expect(query, isNot(startsWith('日本語で')));
    });

    test('lang=viの検索クエリはベトナム語の指示で始まり、「日本語で」を含まない', () {
      final url = PronunciationAiPromptTemplate.evaluationSearchUrl(
        questions: _questions(),
        lang: 'vi',
      );
      final query = url.queryParameters['q']!;
      expect(query, startsWith('Bằng tiếng Việt, '));
      expect(query, isNot(startsWith('日本語で')));
    });
  });
}
