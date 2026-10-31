import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/long_article.dart';
import 'package:osm_gradus/models/long_article_vocab_word.dart';

void main() {
  group('LongArticle.fromJson', () {
    test('旧JSON（語彙テスト関連キー無し）でも落ちず、空/nullで復元できる', () {
      final json = {
        'id': 'la_1',
        'title': 'タイトル',
        'body': '本文',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      };

      final article = LongArticle.fromJson(json);

      expect(article.vocabTestWords, isEmpty);
      expect(article.vocabTestCorrectCount, isNull);
      expect(article.vocabTestQuestionCount, isNull);
      expect(article.lastVocabularyCheckId, isNull);
      expect(article.vocabTestAccuracy, isNull);
      expect(article.hasVocabTestResult, isFalse);
    });

    test('新JSONの語彙テストフィールドを復元できる', () {
      final json = {
        'id': 'la_2',
        'title': 'タイトル',
        'body': '本文',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'vocabTestWords': [
          {
            'word': '観光',
            'reading': 'かんこう',
            'meaningEn': 'sightseeing',
            'meaningVi': 'du lịch',
            'example': '観光地を訪れる。',
            'exampleTranslationEn': 'Visit a tourist spot.',
            'exampleTranslationVi': 'Đến thăm khu du lịch.',
          },
        ],
        'vocabTestCorrectCount': 8,
        'vocabTestQuestionCount': 9,
        'lastVocabularyCheckId': 'check_1',
      };

      final article = LongArticle.fromJson(json);

      expect(article.vocabTestWords, hasLength(1));
      expect(article.vocabTestWords.single.word, '観光');
      expect(article.vocabTestWords.single.meaningFor('en'), 'sightseeing');
      expect(article.vocabTestWords.single.meaningFor('vi'), 'du lịch');
      expect(article.vocabTestWords.single.meaningFor('ja'), 'du lịch');
      expect(article.vocabTestCorrectCount, 8);
      expect(article.vocabTestQuestionCount, 9);
      expect(article.lastVocabularyCheckId, 'check_1');
    });

    test('不正な語彙エントリはスキップし、本文は残る', () {
      final json = {
        'id': 'la_3',
        'title': 'タイトル',
        'body': '本文',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'vocabTestWords': [
          'invalid',
          {'word': '正しい語', 'meaningEn': 'correct', 'meaningVi': 'đúng'},
        ],
      };

      final article = LongArticle.fromJson(json);

      expect(article.body, '本文');
      expect(article.vocabTestWords, hasLength(1));
      expect(article.vocabTestWords.single.word, '正しい語');
    });

    test('toJson後にfromJsonで往復できる', () {
      const word = LongArticleVocabWord(
        word: '経済',
        reading: 'けいざい',
        meaningEn: 'economy',
        meaningVi: 'kinh tế',
      );
      final original = LongArticle(
        id: 'la_4',
        title: 'タイトル',
        body: '本文',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        vocabTestWords: const [word],
        vocabTestCorrectCount: 7,
        vocabTestQuestionCount: 9,
        lastVocabularyCheckId: 'check_2',
      );

      final restored = LongArticle.fromJson(original.toJson());

      expect(restored.vocabTestWords.single.word, '経済');
      expect(restored.vocabTestCorrectCount, 7);
      expect(restored.vocabTestQuestionCount, 9);
      expect(restored.lastVocabularyCheckId, 'check_2');
    });
  });

  group('LongArticle.vocabTestAccuracy', () {
    LongArticle articleWith({int? correct, int? total}) => LongArticle(
      id: 'la',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      vocabTestCorrectCount: correct,
      vocabTestQuestionCount: total,
    );

    test('未実施（両方null）はnull', () {
      expect(articleWith().vocabTestAccuracy, isNull);
    });

    test('出題数0はnull（0除算を避ける）', () {
      expect(
        articleWith(correct: 0, total: 0).vocabTestAccuracy,
        isNull,
      );
    });

    test('9問中8問正解で8/9', () {
      final accuracy = articleWith(correct: 8, total: 9).vocabTestAccuracy;
      expect(accuracy, closeTo(8 / 9, 1e-9));
    });

    test('全問正解で1.0、hasVocabTestResultはtrue', () {
      final article = articleWith(correct: 9, total: 9);
      expect(article.vocabTestAccuracy, 1.0);
      expect(article.hasVocabTestResult, isTrue);
    });
  });

  group('LongArticleVocabWord', () {
    test('meaningFor/exampleTranslationForはenのときのみ英語を返す', () {
      const word = LongArticleVocabWord(
        word: '文化',
        meaningEn: 'culture',
        meaningVi: 'văn hóa',
        exampleTranslationEn: 'Culture example.',
        exampleTranslationVi: 'Ví dụ văn hóa.',
      );

      expect(word.meaningFor('en'), 'culture');
      expect(word.meaningFor('vi'), 'văn hóa');
      expect(word.meaningFor('ja'), 'văn hóa');
      expect(word.exampleTranslationFor('en'), 'Culture example.');
      expect(word.exampleTranslationFor('vi'), 'Ví dụ văn hóa.');
    });
  });
}
