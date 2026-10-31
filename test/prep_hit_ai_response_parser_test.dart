import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/prep_hit_ai_response_parser.dart';

void main() {
  group('PrepHitAiResponseParser', () {
    test('正常なJSONを解析できる', () {
      final result = PrepHitAiResponseParser.parse('''
{"prepStars": 4, "hitStars": 2, "prepAdvice": "結論を先に。", "hitAdvice": "質問に沿って。", "modelAnswer": "週末は、映画を見ます。"}
''');

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.prepStars, 4);
      expect(result.evaluation!.hitStars, 2);
      expect(result.evaluation!.prepAdvice, '結論を先に。');
      expect(result.evaluation!.hitAdvice, '質問に沿って。');
      expect(result.evaluation!.modelAnswer, '週末は、映画を見ます。');
    });

    test('模範回答のローマ字・ベトナム語訳を読み取る（無ければnull）', () {
      final result = PrepHitAiResponseParser.parse(
        '{"prepStars": 4, "hitStars": 4, "modelAnswer": "週末は映画を見ます。", '
        '"modelAnswerRomaji": "Shuumatsu wa eiga o mimasu.", '
        '"modelAnswerVi": "Cuối tuần tôi xem phim."}',
      );
      expect(
        result.evaluation!.modelAnswerRomaji,
        'Shuumatsu wa eiga o mimasu.',
      );
      expect(result.evaluation!.modelAnswerVi, 'Cuối tuần tôi xem phim.');

      final legacy = PrepHitAiResponseParser.parse(
        '{"prepStars": 4, "hitStars": 4, "modelAnswer": "週末は映画を見ます。"}',
      );
      expect(legacy.evaluation!.modelAnswer, '週末は映画を見ます。');
      expect(legacy.evaluation!.modelAnswerRomaji, isNull);
      expect(legacy.evaluation!.modelAnswerVi, isNull);
    });

    test('模範回答が空文字ならnullになる', () {
      final result = PrepHitAiResponseParser.parse(
        '{"prepStars": 2, "hitStars": 2, "modelAnswer": "  "}',
      );

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.modelAnswer, isNull);
    });

    test('前後に説明文が付いていても抽出できる', () {
      final result = PrepHitAiResponseParser.parse('''
以下が評価結果です。
{"prepStars": 3, "hitStars": 5}
ご参考にしてください。
''');

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.prepStars, 3);
      expect(result.evaluation!.hitStars, 5);
    });

    test('範囲外のスコアは1〜5に補正される', () {
      final result = PrepHitAiResponseParser.parse(
        '{"prepStars": 9, "hitStars": 0}',
      );

      expect(result.evaluation!.prepStars, 5);
      expect(result.evaluation!.hitStars, 1);
    });

    test('旧キー（predStars/predAdvice）でも解析できる', () {
      final result = PrepHitAiResponseParser.parse(
        '{"predStars": 3, "hitStars": 4, "predAdvice": "旧アドバイス"}',
      );

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.prepStars, 3);
      expect(result.evaluation!.prepAdvice, '旧アドバイス');
    });

    test('空文字は失敗として扱う', () {
      final result = PrepHitAiResponseParser.parse('');

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
    });

    test('JSONとして解析できない、または必要なキーを持たない場合は失敗する', () {
      final result = PrepHitAiResponseParser.parse('これはJSONではありません');

      expect(result.isSuccess, isFalse);
      expect(result.rawResponse, 'これはJSONではありません');
    });
  });
}
