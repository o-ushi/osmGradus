import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/question_prompt_vocab_extraction_parser.dart';

const _validBatch = '''
{
  "words": [
    {"word": "調整", "reading": "ちょうせい", "pos": "名詞", "jlpt": "N2",
     "meaning": "điều chỉnh", "example": "スケジュールを調整する。",
     "exampleTranslation": "Điều chỉnh lịch trình."},
    {"word": "促進", "reading": "そくしん", "pos": "名詞", "jlpt": "N2",
     "meaning": "thúc đẩy", "example": "経済成長を促進する。",
     "exampleTranslation": "Thúc đẩy tăng trưởng kinh tế."}
  ]
}''';

void main() {
  group('QuestionPromptVocabExtractionParser.parse 正常系', () {
    test('妥当な2件のJSONオブジェクトを取り込める', () {
      final result = QuestionPromptVocabExtractionParser.parse(_validBatch);

      expect(result.isSuccess, isTrue);
      expect(result.words, hasLength(2));
      expect(result.words!.first.word, '調整');
      expect(result.words!.first.reading, 'ちょうせい');
      expect(result.words!.first.pos, '名詞');
      expect(result.words!.first.jlpt, 'N2');
      expect(result.words!.first.meaning, 'điều chỉnh');
      expect(result.words!.first.example, 'スケジュールを調整する。');
      expect(result.words!.first.exampleTranslation, 'Điều chỉnh lịch trình.');
      expect(result.words![1].word, '促進');
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final wrapped = '抽出しました。\n\n```json\n$_validBatch\n```\n\n以上。';
      final result = QuestionPromptVocabExtractionParser.parse(wrapped);

      expect(result.words, hasLength(2));
    });

    test('reading等の任意項目が無くても取り込める（空文字扱い）', () {
      final result = QuestionPromptVocabExtractionParser.parse(
        '{"words": [{"word": "単語"}]}',
      );

      expect(result.words, hasLength(1));
      expect(result.words!.single.word, '単語');
      expect(result.words!.single.reading, '');
      expect(result.words!.single.meaning, '');
    });

    test('一部の要素が壊れていても、その要素だけ読み飛ばして他は保持する', () {
      final result = QuestionPromptVocabExtractionParser.parse(
        '{"words": [{"word": "有効1"}, {"foo": "bar"}, {"word": "有効2"}]}',
      );

      expect(result.words, hasLength(2));
      expect(result.words![0].word, '有効1');
      expect(result.words![1].word, '有効2');
    });

    test('wordが空文字の要素は無効として読み飛ばす', () {
      final result = QuestionPromptVocabExtractionParser.parse(
        '{"words": [{"word": ""}, {"word": "有効"}]}',
      );

      expect(result.words, hasLength(1));
      expect(result.words!.single.word, '有効');
    });

    test('6件以上返ってきても最大5件（maxWords）に切り詰める', () {
      final words = List.generate(7, (i) => '{"word": "単語$i"}').join(',');
      final result = QuestionPromptVocabExtractionParser.parse(
        '{"words": [$words]}',
      );

      expect(result.words, hasLength(5));
      expect(result.words!.first.word, '単語0');
      expect(result.words!.last.word, '単語4');
    });
  });

  group('QuestionPromptVocabExtractionParser.parse 異常系', () {
    test('空文字ならisSuccessがfalse', () {
      final result = QuestionPromptVocabExtractionParser.parse('');

      expect(result.isSuccess, isFalse);
      expect(result.words, isNull);
      expect(result.errorMessage, isNotNull);
    });

    test('JSONとして壊れていればisSuccessがfalse', () {
      final result = QuestionPromptVocabExtractionParser.parse('プレーンテキスト');

      expect(result.isSuccess, isFalse);
      expect(result.words, isNull);
    });

    test('wordsキーが無ければisSuccessがfalse', () {
      final result = QuestionPromptVocabExtractionParser.parse('{"other": []}');

      expect(result.isSuccess, isFalse);
    });

    test('全要素が壊れていればisSuccessがfalse', () {
      final result = QuestionPromptVocabExtractionParser.parse(
        '{"words": [{"foo": "bar"}, {"word": ""}]}',
      );

      expect(result.isSuccess, isFalse);
      expect(result.words, isNull);
    });
  });
}
