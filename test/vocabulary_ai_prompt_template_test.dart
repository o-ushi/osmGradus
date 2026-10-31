import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/vocabulary_ai_prompt_template.dart';
import 'package:osm_gradus/models/vocab_test_session.dart';
import 'package:osm_gradus/models/vocabulary_entry.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';

List<VocabTestQuestion> _questions() {
  final entry = VocabularyEntry(
    id: 'entry1',
    word: '促進',
    reading: 'そくしん',
    translation: 'thúc đẩy',
    level: VocabularyLevel.n1,
    createdAt: DateTime(2026),
  );
  return [
    VocabTestQuestion(
      entry: entry,
      status: VocabTestQuestionStatus.completed,
      sttResult: 'thúc đẩy',
      answerLanguageCode: 'vi',
    ),
  ];
}

void main() {
  group('VocabularyAiPromptTemplate.evaluationPrompt', () {
    test('出題した単語・読み・期待訳・学習者の回答を含む', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'ja',
      );
      expect(prompt, contains('促進'));
      expect(prompt, contains('そくしん'));
      expect(prompt, contains('thúc đẩy'));
      expect(prompt, contains('learnerAnswerLanguage: Vietnamese'));
      expect(prompt, contains('expectedTranslation (Vietnamese): thúc đẩy'));
    });

    test('1秒チェックはChrome AIプロンプトに載せない', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'ja',
      );
      expect(prompt, contains('1. word: 促進'));
      expect(prompt, isNot(contains('readingComprehensionCheck')));
      expect(prompt, isNot(contains('gradedCorrect')));
    });

    test('JSONスキーマはquestionEvaluations/overallScore/summaryを要求する', () {
      for (final lang in ['ja', 'en', 'vi']) {
        final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
          questions: _questions(),
          lang: lang,
        );
        expect(prompt, contains('"questionEvaluations"'));
        expect(prompt, contains('"overallScore"'));
        expect(prompt, contains('"summary"'));
        expect(prompt, contains('"correct"'));
      }
    });

    test('読みが無い単語は reading: を付けない', () {
      final entry = VocabularyEntry(
        id: 'entry2',
        word: 'テスト',
        translation: 'test',
        createdAt: DateTime(2026),
      );
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: [VocabTestQuestion(entry: entry)],
        lang: 'ja',
      );
      expect(prompt, isNot(contains('reading: ')));
    });

    test('未回答の問題はlearnerAnswerが(none)になる', () {
      final entry = VocabularyEntry(
        id: 'entry3',
        word: '概念',
        translation: 'khái niệm',
        createdAt: DateTime(2026),
      );
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: [VocabTestQuestion(entry: entry)],
        lang: 'ja',
      );
      expect(prompt, contains('learnerAnswer: (none)'));
    });

    test('lang=enの指示文はfeedback/summaryを英語で書くよう求める', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'en',
      );
      expect(prompt, contains('Write feedback and summary in English.'));
    });

    test('lang=viの指示文はfeedback/summaryをベトナム語で書くよう求める', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'vi',
      );
      expect(prompt, contains('feedback và summary bằng tiếng Việt.'));
    });

    test('lang=jaの指示文はfeedback/summaryを日本語で書くよう求める', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: _questions(),
        lang: 'ja',
      );
      expect(prompt, contains('feedbackとsummaryは日本語で書いてください。'));
    });
  });

  group('VocabularyAiPromptTemplate.evaluationLaunch', () {
    test('lang=jaの検索クエリは「日本語で」で始まる', () {
      final launch = VocabularyAiPromptTemplate.evaluationLaunch(
        questions: _questions(),
        lang: 'ja',
      );
      final query = launch.url.queryParameters['q'];
      if (query != null) {
        expect(query, startsWith('日本語で'));
      } else {
        expect(launch.url.queryParameters['udm'], '50');
        expect(launch.requiresClipboardPaste, isTrue);
      }
    });

    test('lang=enの検索クエリは英語の指示で始まり、「日本語で」を含まない', () {
      final launch = VocabularyAiPromptTemplate.evaluationLaunch(
        questions: _questions(),
        lang: 'en',
      );
      final query = launch.url.queryParameters['q'];
      if (query != null) {
        expect(query, startsWith('In English, '));
        expect(query, isNot(startsWith('日本語で')));
      }
    });

    test('lang=viの検索クエリはベトナム語の指示で始まり、「日本語で」を含まない', () {
      final launch = VocabularyAiPromptTemplate.evaluationLaunch(
        questions: _questions(),
        lang: 'vi',
      );
      final query = launch.url.queryParameters['q'];
      if (query != null) {
        expect(query, startsWith('Bằng tiếng Việt, '));
        expect(query, isNot(startsWith('日本語で')));
      }
    });

    test('10問分のプロンプトはURLに載せて開く', () {
      final questions = [
        for (var i = 0; i < 10; i++)
          VocabTestQuestion(
            entry: VocabularyEntry(
              id: 'entry$i',
              word: '促進',
              reading: 'そくしん',
              translation: 'thúc đẩy, xúc tiến',
              level: VocabularyLevel.n1,
              createdAt: DateTime(2026),
            ),
            status: VocabTestQuestionStatus.completed,
            sttResult: 'thúc đẩy answer $i',
            answerLanguageCode: 'vi',
          ),
      ];
      final launch = VocabularyAiPromptTemplate.evaluationLaunch(
        questions: questions,
        lang: 'ja',
      );
      expect(launch.requiresClipboardPaste, isFalse);
      expect(launch.url.queryParameters.containsKey('q'), isTrue);
      expect(launch.prompt, contains('learnerAnswer: thúc đẩy answer 0'));
    });

    test('改行を含む回答は1行に正規化される', () {
      final questions = [
        VocabTestQuestion(
          entry: VocabularyEntry(
            id: 'entry1',
            word: '促進',
            translation: 'thúc đẩy',
            createdAt: DateTime(2026),
          ),
          sttResult: 'line1\nline2',
          answerLanguageCode: 'vi',
        ),
      ];
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: questions,
        lang: 'ja',
      );
      expect(prompt, contains('learnerAnswer: line1 line2'));
    });

    test('日本語回答は意味説明として採点する指示を含む', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: [
          VocabTestQuestion(
            entry: VocabularyEntry(
              id: 'entry1',
              word: '促進',
              translation: 'thúc đẩy',
              createdAt: DateTime(2026),
            ),
            sttResult: '物事を進めること',
            answerLanguageCode: 'ja',
          ),
        ],
        lang: 'ja',
      );
      expect(prompt, contains('learnerAnswerLanguage: Japanese'));
      expect(prompt, contains('evaluationCriterion:'));
    });

    test('英語回答は参考訳付きで英語同等訳を許容する', () {
      final prompt = VocabularyAiPromptTemplate.evaluationPrompt(
        questions: [
          VocabTestQuestion(
            entry: VocabularyEntry(
              id: 'entry1',
              word: '促進',
              translation: 'thúc đẩy',
              createdAt: DateTime(2026),
            ),
            sttResult: 'promote',
            answerLanguageCode: 'en',
          ),
        ],
        lang: 'en',
      );
      expect(prompt, contains('learnerAnswerLanguage: English'));
      expect(prompt, contains('referenceTranslation (Vietnamese): thúc đẩy'));
      expect(prompt, contains('accept equivalent English translations'));
    });
  });
}
