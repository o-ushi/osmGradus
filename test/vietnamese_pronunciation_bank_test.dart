import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/vietnamese_pronunciation_bank.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';

void main() {
  group('VietnamesePronunciationBank', () {
    test('組み込み課題は合計25文ある', () {
      expect(VietnamesePronunciationBank.all.length, 25);
    });

    test('各カテゴリに5文ずつある', () {
      for (final category in PronunciationCategory.values) {
        expect(
          VietnamesePronunciationBank.byCategory(category).length,
          5,
          reason: '${category.storageKey}が5文であること',
        );
      }
    });

    test('IDが重複しない', () {
      final ids = VietnamesePronunciationBank.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('IDは安定した命名規則(pron_<category>_<連番>)である', () {
      for (final exercise in VietnamesePronunciationBank.all) {
        expect(
          exercise.id,
          startsWith('pron_${exercise.category.storageKey}_'),
        );
      }
    });

    test('必須文字列が空でない', () {
      for (final exercise in VietnamesePronunciationBank.all) {
        expect(exercise.id, isNotEmpty);
        expect(exercise.sentence, isNotEmpty);
        expect(exercise.reading, isNotEmpty);
        expect(exercise.targetExpressions, isNotEmpty);
        for (final target in exercise.targetExpressions) {
          expect(target, isNotEmpty);
        }
        expect(exercise.vietnameseHint, isNotEmpty);
        expect(exercise.evaluationPoint, isNotEmpty);
      }
    });

    test('全て組み込み(builtIn)課題である', () {
      for (final exercise in VietnamesePronunciationBank.all) {
        expect(exercise.source, PronunciationExerciseSource.builtIn);
      }
    });

    test('targetExpressionsはreadingの部分文字列であり、対象部分が明確である', () {
      for (final exercise in VietnamesePronunciationBank.all) {
        for (final target in exercise.targetExpressions) {
          expect(
            exercise.reading.contains(target),
            isTrue,
            reason:
                '${exercise.id}の targetExpression "$target" が'
                ' reading "${exercise.reading}" に含まれていること',
          );
        }
      }
    });

    test('JSONを往復できる', () {
      for (final exercise in VietnamesePronunciationBank.all) {
        final json = exercise.toJson();
        final restored = PronunciationExercise.fromJson(json);

        expect(restored.id, exercise.id);
        expect(restored.category, exercise.category);
        expect(restored.sentence, exercise.sentence);
        expect(restored.reading, exercise.reading);
        expect(restored.targetExpressions, exercise.targetExpressions);
        expect(restored.vietnameseHint, exercise.vietnameseHint);
        expect(restored.evaluationPoint, exercise.evaluationPoint);
        expect(restored.source, exercise.source);
      }
    });
  });
}
