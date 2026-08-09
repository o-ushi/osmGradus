import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/services/pronunciation_ai_response_parser.dart';

const _validJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 3, "confidence": "medium", "feedbackJa": "「つ」はやや弱いです。", "feedbackVi": "Âm \\"つ\\" hơi yếu.", "evidence": "期待:つくえ / 認識:すくえ"},
    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "良好です。", "feedbackVi": "Tốt.", "evidence": "期待:みず / 認識:みず"},
    "rRow": {"score": 2, "confidence": "low", "feedbackJa": "巻き舌気味です。", "feedbackVi": "Hơi cuộn lưỡi.", "evidence": "期待:りんご / 認識:ринご"},
    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "完璧です。", "feedbackVi": "Hoàn hảo.", "evidence": "期待:くうき / 認識:くうき"},
    "sokuon": {"score": 3, "confidence": "medium", "feedbackJa": "促音がやや短いです。", "feedbackVi": "Âm ngắt hơi ngắn.", "evidence": "期待:きって / 認識:きて"}
  },
  "summaryJa": "全体的に良く練習できています。",
  "summaryVi": "Nhìn chung bạn đã luyện tập tốt."
}''';

void main() {
  group('PronunciationAiResponseParser.parse 正常系', () {
    test('JSONのみの回答を解析できる', () {
      final result = PronunciationAiResponseParser.parse(_validJson);

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.rawResponse, _validJson);

      final evaluation = result.evaluation!;
      expect(evaluation.categoryEvaluations.length, 5);
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.score,
        3,
      );
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.longVowel]!.score,
        5,
      );
      expect(evaluation.summaryJa, '全体的に良く練習できています。');
      expect(evaluation.summaryVi, 'Nhìn chung bạn đã luyện tập tốt.');
    });

    test('AI原文全体がevaluation.rawResponseに保持される', () {
      const withNoise = '前置きの説明文です。\n$_validJson\n以上です。';
      final result = PronunciationAiResponseParser.parse(withNoise);

      expect(result.isSuccess, isTrue);
      expect(result.rawResponse, withNoise);
      expect(result.evaluation!.rawResponse, withNoise);
    });

    test('アプリ側で管理するevaluationVersionが常に補われる', () {
      final result = PronunciationAiResponseParser.parse(_validJson);
      expect(
        result.evaluation!.evaluationVersion,
        PronunciationAiResponseParser.evaluationVersion,
      );
    });

    test('Markdownのコードフェンスで囲まれていても抽出できる', () {
      final wrapped = '以下が評価結果です。\n\n```json\n$_validJson\n```\n\nご参考にしてください。';
      final result = PronunciationAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(
        result.evaluation!.categoryEvaluations[PronunciationCategory.rRow]!.score,
        2,
      );
    });

    test('前後に説明文があってもJSON部分だけを抽出できる', () {
      final wrapped =
          'かしこまりました。発音を分析した結果は次の通りです。\n$_validJson\nご不明な点があればお知らせください。';
      final result = PronunciationAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.categoryEvaluations.length, 5);
    });

    test('文章中に無関係な波括弧が混ざっていても正しいJSONを見つける', () {
      final wrapped = '注記: これは{テスト}用のメモです。\n\n$_validJson';
      final result = PronunciationAiResponseParser.parse(wrapped);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.summaryJa, '全体的に良く練習できています。');
    });

    test('範囲外のscoreは1〜5へ補正される（モデル側の挙動が結合される）', () {
      const jsonWithBadScore = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 0, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "zRow": {"score": 99, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "rRow": {"score": 3, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "longVowel": {"score": 3, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "sokuon": {"score": 3, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"}
  },
  "summaryJa": "s",
  "summaryVi": "t"
}''';
      final result = PronunciationAiResponseParser.parse(jsonWithBadScore);

      expect(result.isSuccess, isTrue);
      expect(
        result.evaluation!.categoryEvaluations[PronunciationCategory.tsu]!.score,
        1,
      );
      expect(
        result.evaluation!.categoryEvaluations[PronunciationCategory.zRow]!.score,
        5,
      );
    });

    test('文字列リテラル内にエスケープされていない生の改行があっても解析できる（AI出力でよくある崩れ方）', () {
      // Chrome AIの回答をそのままコピー＆貼り付けすると、"feedbackJa"のような
      // 長い文章が実際の改行（\n相当のコードポイント）を含んだまま貼り付けられ、
      // \nへエスケープされていないことがある。厳密なjsonDecodeはこれを
      // 構文エラーとして拒否するため、事前に補正できることを確認する。
      const jsonWithRawNewline =
          '{\n'
          '  "categoryEvaluations": {\n'
          '    "tsu": {"score": 3, "confidence": "medium", "feedbackJa": "1行目\n'
          '2行目", "feedbackVi": "a", "evidence": "b"},\n'
          '    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},\n'
          '    "rRow": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},\n'
          '    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},\n'
          '    "sokuon": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"}\n'
          '  },\n'
          '  "summaryJa": "s",\n'
          '  "summaryVi": "t"\n'
          '}';
      final result = PronunciationAiResponseParser.parse(jsonWithRawNewline);

      expect(result.isSuccess, isTrue);
      expect(
        result
            .evaluation!
            .categoryEvaluations[PronunciationCategory.tsu]!
            .feedbackJa,
        '1行目\n2行目',
      );
    });

    test('オブジェクト・配列の末尾に余計なカンマがあっても解析できる（AI出力でよくある崩れ方）', () {
      const jsonWithTrailingCommas = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c",},
    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "rRow": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "sokuon": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
  },
  "summaryJa": "s",
  "summaryVi": "t",
}''';
      final result = PronunciationAiResponseParser.parse(jsonWithTrailingCommas);

      expect(result.isSuccess, isTrue);
      expect(result.evaluation!.categoryEvaluations.length, 5);
    });

    test(
      'フィードバック文中に"th"のようなエスケープされていない引用符が混ざっていても解析できる'
      '（実際にChrome AIが返した回答で発生した崩れ方）',
      () {
        // ベトナム語のフィードバック文中で、AIが引用語をエスケープせず
        // そのまま`"th"` `"ch"`と書いてしまうことがある。厳密なJSONでは
        // これが文字列の終端に見えてしまい構文エラーになるため、
        // 実際に発生した回答と同じ形で解析できることを確認する。
        const jsonWithStrayQuotes = '''
{
  "categoryEvaluations": {
    "tsu": {
      "score": 5,
      "confidence": "high",
      "feedbackJa": "「つ」の発音はバッチリです！",
      "feedbackVi": "Bạn không bị lẫn sang âm "th" hay "ch" mà người Việt thường mắc.",
      "evidence": "期待:つくえ / 認識:つくえ"
    },
    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "rRow": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "sokuon": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"}
  },
  "summaryJa": "s",
  "summaryVi": "t"
}''';
        final result = PronunciationAiResponseParser.parse(jsonWithStrayQuotes);

        expect(result.isSuccess, isTrue);
        expect(
          result
              .evaluation!
              .categoryEvaluations[PronunciationCategory.tsu]!
              .feedbackVi,
          'Bạn không bị lẫn sang âm "th" hay "ch" mà người Việt thường mắc.',
        );
        expect(
          result
              .evaluation!
              .categoryEvaluations[PronunciationCategory.tsu]!
              .score,
          5,
        );
      },
    );
  });

  group('PronunciationAiResponseParser.parse v2スキーマ（feedback/summaryを単一言語で）', () {
    const validEnglishJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 3, "confidence": "medium", "feedback": "The tsu sound is a bit weak.", "evidence": "expected:tsukue / recognized:sukue"},
    "zRow": {"score": 4, "confidence": "high", "feedback": "Good.", "evidence": "expected:mizu / recognized:mizu"},
    "rRow": {"score": 2, "confidence": "low", "feedback": "Slightly rolled.", "evidence": "expected:ringo / recognized:ringo"},
    "longVowel": {"score": 5, "confidence": "high", "feedback": "Perfect.", "evidence": "expected:kuuki / recognized:kuuki"},
    "sokuon": {"score": 3, "confidence": "medium", "feedback": "Slightly short.", "evidence": "expected:kitte / recognized:kite"}
  },
  "summary": "Overall, you are practicing well."
}''';

    test('languageCodeを渡すと、evaluation.feedback/summaryが単一言語のまま解析され、languageCodeも記録される', () {
      final result = PronunciationAiResponseParser.parse(
        validEnglishJson,
        languageCode: 'en',
      );

      expect(result.isSuccess, isTrue);
      final evaluation = result.evaluation!;
      expect(evaluation.languageCode, 'en');
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.feedback,
        'The tsu sound is a bit weak.',
      );
      // v2スキーマはfeedbackJa/feedbackViを持たない（旧形式互換フィールドはnull）。
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.feedbackJa,
        isNull,
      );
      expect(evaluation.displaySummary('en'), 'Overall, you are practicing well.');
    });

    test('languageCodeを省略すると既定値はjaになる', () {
      final result = PronunciationAiResponseParser.parse(validEnglishJson);
      expect(result.evaluation!.languageCode, 'ja');
    });

    test('evaluationVersionはv2になる', () {
      final result = PronunciationAiResponseParser.parse(validEnglishJson);
      expect(result.evaluation!.evaluationVersion, 'v2');
      expect(PronunciationAiResponseParser.evaluationVersion, 'v2');
    });
  });

  group('PronunciationAiResponseParser.parse 異常系', () {
    test('空文字はエラーになり、原文（空文字）を保持する', () {
      final result = PronunciationAiResponseParser.parse('');

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
      expect(result.errorMessage, isNotNull);
      expect(result.rawResponse, '');
    });

    test('空白のみの回答もエラーになる', () {
      final result = PronunciationAiResponseParser.parse('   \n\t  ');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('不正なJSON（構文エラー）でもAI原文を失わない', () {
      const broken = '申し訳ございません、うまく分析できませんでした。{categoryEvaluations: 壊れています';
      final result = PronunciationAiResponseParser.parse(broken);

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
      expect(result.errorMessage, isNotNull);
      expect(result.rawResponse, broken);
    });

    test('JSONオブジェクトが全く含まれない回答でも原文を保持する', () {
      const noJson = 'すみません、うまく評価できませんでした。もう一度お試しください。';
      final result = PronunciationAiResponseParser.parse(noJson);

      expect(result.isSuccess, isFalse);
      expect(result.rawResponse, noJson);
    });

    test('categoryEvaluationsキーを持たないJSONは無効として扱われる', () {
      const wrongShape = '{"foo": "bar", "baz": 123}';
      final result = PronunciationAiResponseParser.parse(wrongShape);

      expect(result.isSuccess, isFalse);
      expect(result.rawResponse, wrongShape);
    });

    test('categoryEvaluationsの型が不正な場合もエラーとして扱われ原文は保持される', () {
      const malformedShape = '{"categoryEvaluations": "not-a-map"}';
      final result = PronunciationAiResponseParser.parse(malformedShape);

      expect(result.isSuccess, isFalse);
      expect(result.evaluation, isNull);
      expect(result.rawResponse, malformedShape);
    });
  });
}
