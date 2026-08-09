import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/pronunciation_practice_session.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/services/pronunciation_exercise_service.dart';

PronunciationPracticeSession _buildSession() {
  final session = const PronunciationExerciseService().buildSession(
    random: Random(1),
  );
  session.completeWithResult('つくえのうえにぺんがあります');
  return session;
}

void main() {
  group('SavedPronunciationCheck.fromSession：unparsedResponseの語彙モデルとの整合', () {
    test('evaluationを省略しunparsedResponseだけ渡した新形式レコードを組み立てられる', () {
      final check = SavedPronunciationCheck.fromSession(
        id: 'unparsed_1',
        sessionId: 'sess_unparsed_1',
        createdAt: DateTime(2026, 1, 1),
        session: _buildSession(),
        unparsedResponse: 'AIのJSONではない回答原文',
      );

      expect(check.sessionId, 'sess_unparsed_1');
      expect(check.evaluation, isNull);
      expect(check.unparsedResponse, 'AIのJSONではない回答原文');
      expect(check.questions, hasLength(10));
    });

    test('sessionIdがあり評価がnullの新形式は旧形式（isLegacyFormat）とみなされない', () {
      final check = SavedPronunciationCheck.fromSession(
        id: 'unparsed_2',
        sessionId: 'sess_unparsed_2',
        createdAt: DateTime(2026, 1, 1),
        session: _buildSession(),
        unparsedResponse: '解析に失敗した原文',
      );

      expect(check.isLegacyFormat, isFalse);
    });

    test('sessionId・evaluationともにない旧形式は引き続きisLegacyFormatがtrueになる', () {
      final legacy = SavedPronunciationCheck(
        id: 'legacy_1',
        createdAt: DateTime(2024, 1, 1),
        transcript: '旧形式の自由記述',
      );

      expect(legacy.isLegacyFormat, isTrue);
    });

    test('toJson/fromJsonでunparsedResponseが往復する', () {
      final original = SavedPronunciationCheck.fromSession(
        id: 'roundtrip_1',
        sessionId: 'sess_roundtrip_1',
        createdAt: DateTime(2026, 3, 3, 10),
        session: _buildSession(),
        unparsedResponse: '往復確認用の原文',
      );

      final restored = SavedPronunciationCheck.fromJson(original.toJson());

      expect(restored.unparsedResponse, '往復確認用の原文');
      expect(restored.evaluation, isNull);
      expect(restored.isLegacyFormat, isFalse);
      expect(restored.sessionId, 'sess_roundtrip_1');
    });

    test('unparsedResponseを指定しなければtoJsonに含まれない', () {
      final legacy = SavedPronunciationCheck(
        id: 'legacy_json_1',
        createdAt: DateTime(2025, 1, 1),
        transcript: '旧形式のテキスト',
      );

      expect(legacy.toJson().containsKey('unparsedResponse'), isFalse);
      expect(legacy.isLegacyFormat, isTrue);
    });
  });
}
