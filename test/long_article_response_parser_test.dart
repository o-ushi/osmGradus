import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/long_article_response_parser.dart';

void main() {
  group('LongArticleResponseParser.parse 正常系', () {
    test('妥当なJSONオブジェクトから本文を取り出せる', () {
      final body = LongArticleResponseParser.parse('{"body": "友達と公園へ行きました。"}');

      expect(body, '友達と公園へ行きました。');
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final body = LongArticleResponseParser.parse(
        '文章です。\n\n```json\n{"body": "今日は天気がいいです。"}\n```\n\n以上。',
      );

      expect(body, '今日は天気がいいです。');
    });

    test('前後の空白はtrimされる', () {
      final body = LongArticleResponseParser.parse('{"body": "  空白テスト  "}');

      expect(body, '空白テスト');
    });
  });

  group('LongArticleResponseParser.parse 異常系', () {
    test('bodyキーが無ければnull', () {
      final body = LongArticleResponseParser.parse('{"title": "無題"}');

      expect(body, isNull);
    });

    test('bodyが空文字ならnull', () {
      final body = LongArticleResponseParser.parse('{"body": ""}');

      expect(body, isNull);
    });

    test('JSONとして壊れていればnull', () {
      final body = LongArticleResponseParser.parse('本文だけのプレーンテキスト');

      expect(body, isNull);
    });
  });

  group('LongArticleResponseParser.parseResult 正常系', () {
    test('body + comprehensionCheckを両方取り出せる（解説は3言語オブジェクト）', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "友達と公園へ行きました。", "comprehensionCheck": {'
        '"question": "誰と行きましたか？", '
        '"optionA": "友達と", '
        '"optionB": "家族と", '
        '"correctOption": "A", '
        '"explanation": {'
        '"ja": "本文に「友達と」とある。", '
        '"en": "The text says \\"with a friend\\".", '
        '"vi": "Văn bản có ghi \\"cùng bạn\\"."'
        '}'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '友達と公園へ行きました。');
      expect(result.comprehensionCheck, isNotNull);
      expect(result.comprehensionCheck!.question, '誰と行きましたか？');
      expect(result.comprehensionCheck!.optionA, '友達と');
      expect(result.comprehensionCheck!.optionB, '家族と');
      expect(result.comprehensionCheck!.correctOption, 'A');
      expect(result.comprehensionCheck!.explanationJa, '本文に「友達と」とある。');
      expect(
        result.comprehensionCheck!.explanationEn,
        'The text says "with a friend".',
      );
      expect(
        result.comprehensionCheck!.explanationVi,
        'Văn bản có ghi "cùng bạn".',
      );
    });
  });

  group('LongArticleResponseParser.parseResult 後方互換', () {
    test('旧形式（bodyのみ）でもbodyは取り出せ、comprehensionCheckはnull', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "今日は天気がいいです。"}',
      );

      expect(result, isNotNull);
      expect(result!.body, '今日は天気がいいです。');
      expect(result.comprehensionCheck, isNull);
    });

    test('解説が旧形式（単一文字列）でも受理し、3言語とも同じ文言になる', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", '
        '"optionA": "A案", '
        '"optionB": "B案", '
        '"correctOption": "A", '
        '"explanation": "旧形式の解説"'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.comprehensionCheck, isNotNull);
      expect(result.comprehensionCheck!.explanationJa, '旧形式の解説');
      expect(result.comprehensionCheck!.explanationEn, '旧形式の解説');
      expect(result.comprehensionCheck!.explanationVi, '旧形式の解説');
    });
  });

  group('LongArticleResponseParser.parseResult 異常系', () {
    test('correctOptionが"C"等の異常値ならcomprehensionCheckはnull（bodyは返る）', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", '
        '"optionA": "A案", '
        '"optionB": "B案", '
        '"correctOption": "C", '
        '"explanation": "解説"'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.comprehensionCheck, isNull);
    });

    test('comprehensionCheckの必須キーが欠落していればnull（bodyは返る）', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", '
        '"optionA": "A案"'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.comprehensionCheck, isNull);
    });

    test('解説オブジェクトの言語キーが欠けていればcomprehensionCheckはnull（bodyは返る）', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", '
        '"optionA": "A案", '
        '"optionB": "B案", '
        '"correctOption": "A", '
        '"explanation": {"ja": "日本語のみ"}'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.comprehensionCheck, isNull);
    });

    test('bodyが無ければparseResult全体がnull', () {
      final result = LongArticleResponseParser.parseResult('{"title": "無題"}');

      expect(result, isNull);
    });
  });

  group('LongArticleResponseParser.parseResult 語彙テスト用単語', () {
    test('body + comprehensionCheck + 9語を正常に取り出せる', () {
      final words = List.generate(
        9,
        (i) =>
            '{"word": "単語$i", "reading": "たんご$i", "pos": "名詞", "jlpt": "N2", '
            '"meaningEn": "word$i", "meaningVi": "từ$i", "example": "例文$i", '
            '"exampleTranslationEn": "example$i", "exampleTranslationVi": "vidu$i"}',
      ).join(',');
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", "optionA": "A案", "optionB": "B案", '
        '"correctOption": "A", "explanation": "解説"'
        '}, "vocabTestWords": [$words]}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.comprehensionCheck, isNotNull);
      expect(result.vocabTestWords, hasLength(9));
      expect(result.vocabTestWords.first.word, '単語0');
      expect(result.vocabTestWords.first.reading, 'たんご0');
      expect(result.vocabTestWords.first.meaningEn, 'word0');
      expect(result.vocabTestWords.first.meaningVi, 'từ0');
      expect(result.vocabTestWords.first.example, '例文0');
      expect(result.vocabTestWords.first.exampleTranslationEn, 'example0');
      expect(result.vocabTestWords.first.exampleTranslationVi, 'vidu0');
    });

    test('旧形式（body+checkのみ、vocabTestWords無し）でもbodyは返り、単語は空配列', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "comprehensionCheck": {'
        '"question": "問題", "optionA": "A案", "optionB": "B案", '
        '"correctOption": "A", "explanation": "解説"'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.vocabTestWords, isEmpty);
    });

    test('旧形式（bodyのみ）でも単語は空配列', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。"}',
      );

      expect(result, isNotNull);
      expect(result!.vocabTestWords, isEmpty);
    });

    test('壊れた語（Mapでない要素、meaningEn/meaningVi両方空、word無し）はスキップし本文は残る', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "vocabTestWords": ['
        '"invalid_not_a_map", '
        '{"word": "訳なし語", "meaningEn": "", "meaningVi": ""}, '
        '{"word": "", "meaningEn": "no word", "meaningVi": ""}, '
        '{"word": "正しい語", "meaningEn": "correct", "meaningVi": "đúng"}'
        ']}',
      );

      expect(result, isNotNull);
      expect(result!.body, '本文です。');
      expect(result.vocabTestWords, hasLength(1));
      expect(result.vocabTestWords.single.word, '正しい語');
    });

    test('10語来たら9語にtruncateされる', () {
      final words = List.generate(
        10,
        (i) =>
            '{"word": "単語$i", "meaningEn": "word$i", "meaningVi": "từ$i"}',
      ).join(',');
      final result = LongArticleResponseParser.parseResult(
        '{"body": "本文です。", "vocabTestWords": [$words]}',
      );

      expect(result, isNotNull);
      expect(result!.vocabTestWords, hasLength(9));
      expect(result.vocabTestWords.last.word, '単語8');
    });
  });
}
