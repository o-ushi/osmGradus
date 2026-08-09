import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/services/pronunciation_exercise_import_parser.dart';

const _validBatch = '''
[
  {"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "vi1", "evaluationPoint": "ja1"},
  {"category": "zRow", "sentence": "水をください。", "reading": "みずをください。", "targetExpressions": ["みず"], "vietnameseHint": "vi2", "evaluationPoint": "ja2"},
  {"category": "rRow", "sentence": "りんごを食べます。", "reading": "りんごをたべます。", "targetExpressions": ["りんご"], "vietnameseHint": "vi3", "evaluationPoint": "ja3"},
  {"category": "longVowel", "sentence": "空気がきれいです。", "reading": "くうきがきれいです。", "targetExpressions": ["くうき"], "vietnameseHint": "vi4", "evaluationPoint": "ja4"},
  {"category": "sokuon", "sentence": "切手を買います。", "reading": "きってをかいます。", "targetExpressions": ["きって"], "vietnameseHint": "vi5", "evaluationPoint": "ja5"}
]''';

void main() {
  group('PronunciationExerciseImportParser.parse 正常系', () {
    test('妥当な5件のJSON配列をすべて取り込める', () {
      final result = PronunciationExerciseImportParser.parse(_validBatch);

      expect(result.exercises, hasLength(5));
      expect(result.rejectedCount, 0);
      expect(result.isEmpty, isFalse);
      for (final exercise in result.exercises) {
        expect(exercise.source, PronunciationExerciseSource.imported);
      }
      expect(
        result.exercises
            .map((e) => e.category)
            .toSet(),
        PronunciationCategory.values.toSet(),
      );
    });

    test('targetExpressionsが単一文字列でもリストとして扱える', () {
      const json = '''
[{"category": "tsu", "sentence": "強い風です。", "reading": "つよいかぜです。", "targetExpressions": "つよい", "vietnameseHint": "v", "evaluationPoint": "e"}]''';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, hasLength(1));
      expect(result.exercises.single.targetExpressions, ['つよい']);
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final wrapped =
          '発音課題を作成しました。\n\n```json\n$_validBatch\n```\n\nご確認ください。';
      final result = PronunciationExerciseImportParser.parse(wrapped);

      expect(result.exercises, hasLength(5));
    });

    test('同じカテゴリ・文・読みからは常に同じIDが生成される（安定ID）', () {
      final result1 = PronunciationExerciseImportParser.parse(_validBatch);
      final result2 = PronunciationExerciseImportParser.parse(_validBatch);

      final ids1 = result1.exercises.map((e) => e.id).toList();
      final ids2 = result2.exercises.map((e) => e.id).toList();
      expect(ids1, ids2);
    });

    test('配列・オブジェクトの末尾に余計なカンマがあっても解析できる（AI出力でよくある崩れ方）', () {
      const jsonWithTrailingCommas = '''
[
  {"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ",], "vietnameseHint": "vi1", "evaluationPoint": "ja1",},
]''';
      final result = PronunciationExerciseImportParser.parse(
        jsonWithTrailingCommas,
      );

      expect(result.exercises, hasLength(1));
      expect(result.rejectedCount, 0);
    });

    test(
      'ヒント文中に"th"のようなエスケープされていない引用符が混ざっていても解析できる'
      '（PronunciationAiResponseParserと共通のAiJsonExtractorが吸収する）',
      () {
        const jsonWithStrayQuotes = '''
[{"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "Bạn không bị lẫn sang âm "th" hay "ch"", "evaluationPoint": "ja1"}]''';
        final result = PronunciationExerciseImportParser.parse(
          jsonWithStrayQuotes,
        );

        expect(result.exercises, hasLength(1));
        expect(
          result.exercises.single.vietnameseHint,
          'Bạn không bị lẫn sang âm "th" hay "ch"',
        );
      },
    );
  });

  group('PronunciationExerciseImportParser.parse カテゴリ・対象音の整合性検証', () {
    test('対象音がreadingに含まれない場合は除外される', () {
      const json = '''
[{"category": "sokuon", "sentence": "普通の文です。", "reading": "ふつうのぶんです。", "targetExpressions": ["ふつう"], "vietnameseHint": "v", "evaluationPoint": "e"}]''';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, isEmpty);
      expect(result.rejectedCount, 1);
    });

    test('targetExpressionsがreadingに含まれない場合は除外される', () {
      const json = '''
[{"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["ありえない文字列"], "vietnameseHint": "v", "evaluationPoint": "e"}]''';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, isEmpty);
      expect(result.rejectedCount, 1);
    });

    test('不明なcategory値は除外される', () {
      const json = '''
[{"category": "unknownCategory", "sentence": "s", "reading": "s", "targetExpressions": ["s"], "vietnameseHint": "v", "evaluationPoint": "e"}]''';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, isEmpty);
      expect(result.rejectedCount, 1);
    });

    test('必須項目（sentence/reading/vietnameseHint/evaluationPoint）が空だと除外される', () {
      const json = '''
[{"category": "tsu", "sentence": "", "reading": "つくえ", "targetExpressions": ["つくえ"], "vietnameseHint": "v", "evaluationPoint": "e"}]''';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, isEmpty);
      expect(result.rejectedCount, 1);
    });
  });

  group('PronunciationExerciseImportParser.parse 不完全な回答への耐性', () {
    test('一部が不正でも有効な項目だけを取り込む', () {
      const mixed = '''
[
  {"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "v", "evaluationPoint": "e"},
  {"category": "invalid", "sentence": "s", "reading": "s", "targetExpressions": ["s"], "vietnameseHint": "v", "evaluationPoint": "e"},
  {"category": "sokuon"},
  {"category": "rRow", "sentence": "りんごを食べます。", "reading": "りんごをたべます。", "targetExpressions": ["りんご"], "vietnameseHint": "v", "evaluationPoint": "e"}
]''';
      final result = PronunciationExerciseImportParser.parse(mixed);

      expect(result.exercises, hasLength(2));
      expect(result.rejectedCount, 2);
      expect(
        result.exercises.map((e) => e.category),
        [PronunciationCategory.tsu, PronunciationCategory.rRow],
      );
    });

    test('バッチ内でID・文・読みが重複する項目は除外される', () {
      const duplicated = '''
[
  {"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "v1", "evaluationPoint": "e1"},
  {"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "v2", "evaluationPoint": "e2"}
]''';
      final result = PronunciationExerciseImportParser.parse(duplicated);

      expect(result.exercises, hasLength(1));
      expect(result.rejectedCount, 1);
    });

    test('JSON配列が全く含まれない回答は空の結果になる（例外を投げない）', () {
      final result = PronunciationExerciseImportParser.parse(
        'すみません、うまく作成できませんでした。',
      );

      expect(result.exercises, isEmpty);
      expect(result.rejectedCount, 0);
      expect(result.isEmpty, isTrue);
    });

    test('空文字でも例外を投げない', () {
      final result = PronunciationExerciseImportParser.parse('');
      expect(result.exercises, isEmpty);
    });

    test('配列の要素がオブジェクトでない場合は除外される', () {
      const json = '[{"category": "tsu", "sentence": "机の上にペンがあります。", "reading": "つくえのうえにぺんがあります。", "targetExpressions": ["つくえ"], "vietnameseHint": "v", "evaluationPoint": "e"}, "文字列だけの要素"]';
      final result = PronunciationExerciseImportParser.parse(json);

      expect(result.exercises, hasLength(1));
      expect(result.rejectedCount, 1);
    });
  });
}
