import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/pronunciation_practice_session.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/services/gradus_backup.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/pronunciation_exercise_service.dart';

PronunciationCategoryEvaluation _categoryEval({
  int score = 4,
  PronunciationConfidence confidence = PronunciationConfidence.medium,
}) => PronunciationCategoryEvaluation(
  score: score,
  confidence: confidence,
  feedbackJa: 'よくできています。',
  feedbackVi: 'Làm tốt lắm.',
  evidence: '期待:「つくえ」/ 認識:「つくえ」',
);

PronunciationEvaluation _buildEvaluation() => PronunciationEvaluation(
  categoryEvaluations: {
    for (final category in PronunciationCategory.values)
      category: _categoryEval(score: category.index + 1),
  },
  summaryJa: '全体的に発音は安定しています。',
  summaryVi: 'Phát âm nhìn chung ổn định.',
  rawResponse: '{"raw":"chrome-ai-response"}',
  evaluationVersion: 'v1',
);

SavedPronunciationCheck _buildNewFormatCheck({
  required String id,
  required String sessionId,
  DateTime? createdAt,
}) {
  final session = const PronunciationExerciseService().buildSession(
    random: Random(1),
  );
  session.completeWithResult('つくえのうえにぺんがあります');
  session.next();
  session.markFailed();

  return SavedPronunciationCheck.fromSession(
    id: id,
    sessionId: sessionId,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 10),
    session: session,
    evaluation: _buildEvaluation(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PronunciationCheckStorage 新形式', () {
    test('10問セッションと5カテゴリ評価をsave/loadAllで往復できる', () async {
      final storage = PronunciationCheckStorage();
      final check = _buildNewFormatCheck(id: 'new_1', sessionId: 'sess_1');
      await storage.save(check);

      final loaded = await storage.loadAll();
      expect(loaded, hasLength(1));
      final restored = loaded.single;

      expect(restored.id, 'new_1');
      expect(restored.sessionId, 'sess_1');
      expect(restored.isLegacyFormat, isFalse);
      expect(restored.transcript, '');
      expect(restored.questions, hasLength(10));

      final firstQuestion = restored.questions!.first;
      expect(firstQuestion.sttResult, 'つくえのうえにぺんがあります');
      expect(firstQuestion.status, PronunciationQuestionStatus.completed);
      final secondQuestion = restored.questions![1];
      expect(secondQuestion.status, PronunciationQuestionStatus.failed);

      expect(restored.evaluation, isNotNull);
      expect(restored.evaluation!.evaluationVersion, 'v1');
      expect(restored.evaluation!.rawResponse, '{"raw":"chrome-ai-response"}');
      expect(restored.evaluation!.categoryEvaluations.length, 5);
      expect(
        restored
            .evaluation!
            .categoryEvaluations[PronunciationCategory.tsu]!
            .score,
        1,
      );
    });
  });

  group('PronunciationCheckStorage 旧形式との互換性', () {
    test('id/createdAt/transcriptだけの旧形式レコードを保存・復元できる', () async {
      final storage = PronunciationCheckStorage();
      final legacyCheck = SavedPronunciationCheck(
        id: 'legacy_1',
        createdAt: DateTime(2025, 6, 1, 9),
        transcript: '「つ」の発音がやや弱いです。',
      );
      await storage.save(legacyCheck);

      final loaded = await storage.loadAll();
      expect(loaded, hasLength(1));
      final restored = loaded.single;

      expect(restored.transcript, '「つ」の発音がやや弱いです。');
      expect(restored.sessionId, isNull);
      expect(restored.questions, isNull);
      expect(restored.evaluation, isNull);
      expect(restored.isLegacyFormat, isTrue);
    });

    test('id/createdAt/transcriptのみの生JSON文字列を直接読み込める', () async {
      final prefs = await SharedPreferences.getInstance();
      final rawLegacyJson = jsonEncode({
        'id': 'raw_legacy_1',
        'createdAt': DateTime(2024, 3, 3).toIso8601String(),
        'transcript': '旧バージョンのフィードバック本文',
      });
      await prefs.setStringList('layer5.pronunciationChecks', [rawLegacyJson]);

      final storage = PronunciationCheckStorage();
      final loaded = await storage.loadAll();

      expect(loaded, hasLength(1));
      expect(loaded.single.transcript, '旧バージョンのフィードバック本文');
      expect(loaded.single.isLegacyFormat, isTrue);
    });
  });

  group('PronunciationCheckStorage 欠損・不正データへの耐性', () {
    test('未知フィールドが混ざっていても読み込める', () async {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode({
        'id': 'unknown_field_1',
        'createdAt': DateTime(2026, 2, 2).toIso8601String(),
        'transcript': '',
        'sessionId': 'sess_x',
        'futureField': {'nested': 'data'},
        'questions': [],
      });
      await prefs.setStringList('layer5.pronunciationChecks', [rawJson]);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.sessionId, 'sess_x');
      expect(loaded.single.questions, isEmpty);
    });

    test('questions内の1件が壊れていてもそれだけ読み飛ばす', () async {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode({
        'id': 'partial_questions_1',
        'createdAt': DateTime(2026, 2, 2).toIso8601String(),
        'transcript': '',
        'questions': [
          {
            'exerciseId': 'pron_tsu_01',
            'category': 'tsu',
            'sentence': '机の上にペンがあります。',
            'status': 'completed',
            'sttResult': 'つくえのうえにぺんがあります',
          },
          {'exerciseId': 'broken_entry_missing_category'},
        ],
      });
      await prefs.setStringList('layer5.pronunciationChecks', [rawJson]);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.questions, hasLength(1));
      expect(loaded.single.questions!.single.exerciseId, 'pron_tsu_01');
    });

    test('evaluationが壊れていてもレコード自体は読み込める', () async {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode({
        'id': 'broken_evaluation_1',
        'createdAt': DateTime(2026, 2, 2).toIso8601String(),
        'transcript': '',
        'sessionId': 'sess_y',
        'evaluation': {'categoryEvaluations': 'not-a-map'},
      });
      await prefs.setStringList('layer5.pronunciationChecks', [rawJson]);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.sessionId, 'sess_y');
      expect(loaded.single.evaluation, isNull);
    });

    test('1件の破損したJSON文字列は読み飛ばし、他の正常な結果は読み込む', () async {
      final prefs = await SharedPreferences.getInstance();
      final validJson = jsonEncode({
        'id': 'valid_1',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'transcript': '正常なデータ',
      });
      await prefs.setStringList('layer5.pronunciationChecks', [
        '{this is not valid json',
        validJson,
      ]);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'valid_1');
    });
  });

  group('GradusBackup エクスポート・インポート往復', () {
    test('新形式レコードを含むエクスポートJSONは現行のformatVersionになる', () async {
      await PronunciationCheckStorage().save(
        _buildNewFormatCheck(id: 'export_1', sessionId: 'sess_export'),
      );

      final json = await GradusBackup.buildExportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['version'], GradusBackup.formatVersion);
      final checks = decoded['pronunciationChecks'] as List;
      expect(checks, hasLength(1));
      final exported = checks.single as Map<String, dynamic>;
      expect(exported['sessionId'], 'sess_export');
      expect(exported['evaluation'], isNotNull);
    });

    test('新形式（v2）でエクスポートしたJSONを別ストレージへ往復インポートできる', () async {
      await PronunciationCheckStorage().save(
        _buildNewFormatCheck(id: 'roundtrip_1', sessionId: 'sess_roundtrip'),
      );
      final exportedJson = await GradusBackup.buildExportJson();

      // インポート先を空にしてから取り込む。
      SharedPreferences.setMockInitialValues({});
      final result = await GradusBackup.importFromContent(exportedJson);

      expect(result.added, 1);
      expect(result.skipped, 0);
      expect(result.sourceVersion, GradusBackup.formatVersion);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.sessionId, 'sess_roundtrip');
      expect(loaded.single.evaluation, isNotNull);
      expect(loaded.single.questions, hasLength(10));
    });

    test('旧形式（version省略・transcriptのみ）バックアップも引き続きインポートできる', () async {
      final legacyBackup = jsonEncode({
        'exportDate': DateTime(2024, 1, 1).toIso8601String(),
        'pronunciationChecks': [
          {
            'id': 'legacy_backup_1',
            'createdAt': DateTime(2024, 1, 1).toIso8601String(),
            'transcript': '旧バックアップのフィードバック',
          },
        ],
      });

      final result = await GradusBackup.importFromContent(legacyBackup);

      expect(result.added, 1);
      expect(result.skipped, 0);
      expect(result.sourceVersion, 1);

      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.transcript, '旧バックアップのフィードバック');
      expect(loaded.single.isLegacyFormat, isTrue);
    });

    test('version:1を明示した旧バックアップもインポートできる', () async {
      final legacyBackupV1 = jsonEncode({
        'version': 1,
        'pronunciationChecks': [
          {
            'id': 'legacy_v1_1',
            'createdAt': DateTime(2024, 1, 1).toIso8601String(),
            'transcript': 'v1明示のフィードバック',
          },
        ],
      });

      final result = await GradusBackup.importFromContent(legacyBackupV1);

      expect(result.sourceVersion, 1);
      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded.single.transcript, 'v1明示のフィードバック');
    });

    test('同じidのレコードは重複インポートされずスキップされる', () async {
      final check = _buildNewFormatCheck(id: 'dup_1', sessionId: 'sess_dup');
      await PronunciationCheckStorage().save(check);
      final exportedJson = await GradusBackup.buildExportJson();

      // 同じストレージにもう一度インポート（idは既存のまま）。
      final result = await GradusBackup.importFromContent(exportedJson);

      expect(result.added, 0);
      expect(result.skipped, 1);
      final loaded = await PronunciationCheckStorage().loadAll();
      expect(loaded, hasLength(1));
    });
  });
}
