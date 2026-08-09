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
}
