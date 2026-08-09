import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/long_article_vocab_translation_parser.dart';

const _validBatch = '''
[
  {"reading": "ともだち", "translation": "bạn bè", "exampleSentence": "友達と遊んだ。"},
  {"reading": "こうえん", "translation": "công viên", "exampleSentence": "公園で走った。"}
]''';

void main() {
  group('LongArticleVocabTranslationParser.parse 正常系', () {
    test('妥当な2件のJSON配列を、依頼順のまま取り込める', () {
      final result = LongArticleVocabTranslationParser.parse(_validBatch);

      expect(result.isSuccess, isTrue);
      expect(result.entries, hasLength(2));
      expect(result.entries!.first!.reading, 'ともだち');
      expect(result.entries!.first!.translation, 'bạn bè');
      expect(result.entries!.first!.exampleSentence, '友達と遊んだ。');
      expect(result.entries![1]!.translation, 'công viên');
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final wrapped = '訳を付けました。\n\n```json\n$_validBatch\n```\n\n以上。';
      final result = LongArticleVocabTranslationParser.parse(wrapped);

      expect(result.entries, hasLength(2));
    });

    test('readingやexampleSentenceが無くても取り込める（空文字扱い）', () {
      final result = LongArticleVocabTranslationParser.parse(
        '[{"translation": "bạn bè"}]',
      );

      expect(result.entries, hasLength(1));
      expect(result.entries!.single!.reading, '');
      expect(result.entries!.single!.exampleSentence, '');
    });

    test('一部の要素が壊れていても、その位置だけnullにして他は保持する'
        '（位置がずれて別の単語に誤って割り当たらないようにするため）', () {
      final result = LongArticleVocabTranslationParser.parse(
        '[{"translation": "bạn bè"}, {"foo": "bar"}, '
        '{"translation": "công viên"}]',
      );

      expect(result.entries, hasLength(3));
      expect(result.entries![0]!.translation, 'bạn bè');
      expect(result.entries![1], isNull);
      expect(result.entries![2]!.translation, 'công viên');
    });
  });

  group('LongArticleVocabTranslationParser.parse 異常系', () {
    test('空文字ならisSuccessがfalse', () {
      final result = LongArticleVocabTranslationParser.parse('');

      expect(result.isSuccess, isFalse);
      expect(result.entries, isNull);
      expect(result.errorMessage, isNotNull);
    });

    test('JSONとして壊れていればisSuccessがfalse', () {
      final result = LongArticleVocabTranslationParser.parse('プレーンテキスト');

      expect(result.isSuccess, isFalse);
      expect(result.entries, isNull);
    });
  });
}
