import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/long_article_response_parser.dart';

void main() {
  group('LongArticleResponseParser.parse 正常系', () {
    test('妥当なJSONオブジェクトから本文を取り出せる', () {
      final body = LongArticleResponseParser.parse(
        '{"body": "友達と公園へ行きました。"}',
      );

      expect(body, '友達と公園へ行きました。');
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final body = LongArticleResponseParser.parse(
        '文章です。\n\n```json\n{"body": "今日は天気がいいです。"}\n```\n\n以上。',
      );

      expect(body, '今日は天気がいいです。');
    });

    test('前後の空白はtrimされる', () {
      final body = LongArticleResponseParser.parse(
        '{"body": "  空白テスト  "}',
      );

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
    test('body + comprehensionCheckを両方取り出せる', () {
      final result = LongArticleResponseParser.parseResult(
        '{"body": "友達と公園へ行きました。", "comprehensionCheck": {'
        '"question": "誰と行きましたか？", '
        '"optionA": "友達と", '
        '"optionB": "家族と", '
        '"correctOption": "A", '
        '"explanation": "本文に「友達と」とある。"'
        '}}',
      );

      expect(result, isNotNull);
      expect(result!.body, '友達と公園へ行きました。');
      expect(result.comprehensionCheck, isNotNull);
      expect(result.comprehensionCheck!.question, '誰と行きましたか？');
      expect(result.comprehensionCheck!.optionA, '友達と');
      expect(result.comprehensionCheck!.optionB, '家族と');
      expect(result.comprehensionCheck!.correctOption, 'A');
      expect(result.comprehensionCheck!.explanation, '本文に「友達と」とある。');
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

    test('bodyが無ければparseResult全体がnull', () {
      final result = LongArticleResponseParser.parseResult('{"title": "無題"}');

      expect(result, isNull);
    });
  });
}
