import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/vocabulary_ai_response_parser.dart';

const _validJson = '''
{
  "questionEvaluations": [
    {"correct": true, "feedback": "正解です。"},
    {"correct": false, "feedback": "惜しいです。「促す」のニュアンスが抜けています。"}
  ],
  "overallScore": 4,
  "summary": "全体的に良く理解できています。"
}''';

void main() {
  group('VocabularyAiResponseParser.parse 正常系', () {
    test('JSONのみの回答を解析できる', () {
      final result = VocabularyAiResponseParser.parse(_validJson);

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.rawResponse, _validJson);

      final evaluation = result.evaluation!;
      expect(evaluation.overallScore, 4);
      expect(evaluation.summary, '全体的に良く理解できています。');
      expect(evaluation.questionEvaluations.length, 2);
      expect(evaluation.questionEvaluations[0].correct, isTrue);
      expect(evaluation.questionEvaluations[1].correct, isFalse);
    });

    test('AI原文全体がevaluation.rawResponseに保持される', () {
      const withNoise = '前置きの説明文です。\n$_validJson\n以上です。';
      final result = VocabularyAiResponseParser.parse(withNoise);

      expect(result.isSuccess, isTrue);
      expect(result.rawResponse, withNoise);
      expect(result.evaluation!.rawResponse, withNoise);
    });

    test('アプリ側で管理するevaluationVersionが常に補われる', () {
      final result = VocabularyAiResponseParser.parse(_validJson);
      expect(
        result.evaluation!.evaluationVersion,
        VocabularyAiResponseParser.evaluationVersion,
      );
    });

    test('languageCodeを渡すとevaluation.languageCodeに記録される', () {
      final result = VocabularyAiResponseParser.parse(
        _validJson,
        languageCode: 'vi',
      );
      expect(result.evaluation!.languageCode, 'vi');
    });

    test('languageCodeを省略すると既定値はjaになる', () {
      final result = VocabularyAiResponseParser.parse(_validJson);
      expect(result.evaluation!.languageCode, 'ja');
    });

    test('Markdownのコードフェンスで囲まれていても抽出できる', () {
      final wrapped = '以下が評価結果です。\n\n```json\n$_validJson\n```\n\nご参考にしてください。';
      final result = VocabularyAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.overallScore, 4);
    });

    test('前後に説明文があってもJSON部分だけを抽出できる', () {
      final wrapped =
          'かしこまりました。語彙力を分析した結果は次の通りです。\n$_validJson\nご不明な点があればお知らせください。';
      final result = VocabularyAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.questionEvaluations.length, 2);
    });

    test('文章中に無関係な波括弧が混ざっていても正しいJSONを見つける', () {
      final wrapped = '注記: これは{テスト}用のメモです。\n\n$_validJson';
      final result = VocabularyAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.summary, '全体的に良く理解できています。');
    });

    test('範囲外のoverallScoreは1〜5へ補正される（モデル側の挙動が結合される）', () {
      const jsonWithBadScore = '''
{
  "questionEvaluations": [{"correct": true, "feedback": "a"}],
  "overallScore": 99,
  "summary": "s"
}''';
      final result = VocabularyAiResponseParser.parse(jsonWithBadScore);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.overallScore, 5);
    });

    test('オブジェクト・配列の末尾に余計なカンマがあっても解析できる（AI出力でよくある崩れ方）', () {
      const jsonWithTrailingCommas = '''
{
  "questionEvaluations": [
    {"correct": true, "feedback": "a",},
    {"correct": false, "feedback": "b",},
  ],
  "overallScore": 3,
  "summary": "s",
}''';
      final result = VocabularyAiResponseParser.parse(jsonWithTrailingCommas);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.questionEvaluations.length, 2);
    });
  });

  group('VocabularyAiResponseParser.parse 異常系', () {
    test('空文字はエラーになり、原文（空文字）を保持する', () {
      final result = VocabularyAiResponseParser.parse('');

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
      expect(result.errorMessage, isNotNull);
      expect(result.rawResponse, '');
    });

    test('空白のみの回答もエラーになる', () {
      final result = VocabularyAiResponseParser.parse('   \n\t  ');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('不正なJSON（構文エラー）でもAI原文を失わない', () {
      const broken = '申し訳ございません、うまく分析できませんでした。{overallScore: 壊れています';
      final result = VocabularyAiResponseParser.parse(broken);

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
      expect(result.errorMessage, isNotNull);
      expect(result.rawResponse, broken);
    });

    test('JSONオブジェクトが全く含まれない回答でも原文を保持する', () {
      const noJson = 'すみません、うまく評価できませんでした。もう一度お試しください。';
      final result = VocabularyAiResponseParser.parse(noJson);

      expect(result.isSuccess, isFalse);
      expect(result.rawResponse, noJson);
    });

    test('overallScoreキーを持たないJSONは無効として扱われる', () {
      const wrongShape = '{"foo": "bar", "baz": 123}';
      final result = VocabularyAiResponseParser.parse(wrongShape);

      expect(result.isSuccess, isFalse);
      expect(result.rawResponse, wrongShape);
    });

    test('questionEvaluationsを省略した場合は空配列として扱われる', () {
      const missingQuestions = '{"overallScore": 3, "summary": "s"}';
      final result = VocabularyAiResponseParser.parse(missingQuestions);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.questionEvaluations, isEmpty);
    });
  });
}
