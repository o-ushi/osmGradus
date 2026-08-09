import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/data/vietnamese_pronunciation_bank.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/pronunciation_practice_session.dart';
import 'package:osm_gradus/services/pronunciation_exercise_service.dart';

PronunciationExercise _importedExercise({
  required String id,
  PronunciationCategory category = PronunciationCategory.tsu,
  String sentence = 'テスト文です。',
  String reading = 'てすとぶんです。',
  List<String> targetExpressions = const ['てすと'],
}) => PronunciationExercise(
  id: id,
  category: category,
  sentence: sentence,
  reading: reading,
  targetExpressions: targetExpressions,
  vietnameseHint: 'vi',
  evaluationPoint: 'ja',
  source: PronunciationExerciseSource.imported,
);

void main() {
  group('PronunciationExerciseService.buildSession', () {
    test('合計10問になる', () {
      final session = const PronunciationExerciseService().buildSession(
        random: Random(1),
      );
      expect(session.questionCount, 10);
    });

    test('各カテゴリ2問ずつになる', () {
      final session = const PronunciationExerciseService().buildSession(
        random: Random(1),
      );
      for (final category in PronunciationCategory.values) {
        final count = session.questions
            .where((q) => q.exercise.category == category)
            .length;
        expect(count, 2, reason: '${category.storageKey}が2問であること');
      }
    });

    test('同一セッション内で課題IDが重複しない', () {
      final session = const PronunciationExerciseService().buildSession(
        random: Random(42),
      );
      final ids = session.questions.map((q) => q.exercise.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('同じseedなら同じ結果になる', () {
      final serviceA = const PronunciationExerciseService();
      final serviceB = const PronunciationExerciseService();

      final sessionA = serviceA.buildSession(random: Random(7));
      final sessionB = serviceB.buildSession(random: Random(7));

      final idsA = sessionA.questions.map((q) => q.exercise.id).toList();
      final idsB = sessionB.questions.map((q) => q.exercise.id).toList();

      expect(idsA, idsB);
    });

    test('異なるseedなら順序または内容が変わりうる', () {
      final session1 = const PronunciationExerciseService().buildSession(
        random: Random(1),
      );
      final session2 = const PronunciationExerciseService().buildSession(
        random: Random(2),
      );

      final ids1 = session1.questions.map((q) => q.exercise.id).toList();
      final ids2 = session2.questions.map((q) => q.exercise.id).toList();

      expect(ids1, isNot(equals(ids2)));
    });

    test('問題順はカテゴリ順に固定されない', () {
      final session = const PronunciationExerciseService().buildSession(
        random: Random(3),
      );
      final categoryOrder = session.questions
          .map((q) => q.exercise.category)
          .toList();
      final fixedCategoryOrder = [
        for (final category in PronunciationCategory.values) ...[
          category,
          category,
        ],
      ];
      expect(categoryOrder, isNot(equals(fixedCategoryOrder)));
    });

    test('プールが25問未満でも安全に抽選できる', () {
      final smallPool = VietnamesePronunciationBank.byCategory(
        PronunciationCategory.tsu,
      ).take(1).toList();

      final session = const PronunciationExerciseService().buildSession(
        pool: smallPool,
        random: Random(1),
      );

      expect(session.questionCount, 1);
      expect(session.questions.single.exercise.category, PronunciationCategory.tsu);
    });

    test('プールが空でも例外を投げない', () {
      final session = const PronunciationExerciseService().buildSession(
        pool: const [],
        random: Random(1),
      );
      expect(session.questionCount, 0);
    });
  });

  group('PronunciationPracticeSession navigation', () {
    late PronunciationPracticeSession session;

    setUp(() {
      session = const PronunciationExerciseService().buildSession(
        random: Random(5),
      );
    });

    test('next()で次の問題に進み、最後では止まる', () {
      expect(session.currentIndex, 0);
      session.next();
      expect(session.currentIndex, 1);

      for (var i = 0; i < session.questionCount; i++) {
        session.next();
      }
      expect(session.currentIndex, session.questionCount - 1);
    });

    test('previous()で前の問題に戻り、最初では止まる', () {
      session.next();
      session.next();
      expect(session.currentIndex, 2);

      session.previous();
      expect(session.currentIndex, 1);

      session.previous();
      session.previous();
      expect(session.currentIndex, 0);
    });

    test('completeWithResult()でSTT結果が記録されcompletedになる', () {
      session.completeWithResult('こんにちは');
      expect(session.current.sttResult, 'こんにちは');
      expect(session.current.status, PronunciationQuestionStatus.completed);
    });

    test('retryCurrent()（再録音）で状態がwaitingに戻りSTT結果が消える', () {
      session.completeWithResult('こんにちは');
      session.retryCurrent();

      expect(session.current.status, PronunciationQuestionStatus.waiting);
      expect(session.current.sttResult, isNull);
    });

    test('再録音は現在の問題にのみ影響し、他の問題の状態は変わらない', () {
      session.completeWithResult('1問目の結果');
      session.next();
      session.completeWithResult('2問目の結果');

      session.retryCurrent();

      expect(session.current.status, PronunciationQuestionStatus.waiting);
      expect(session.current.sttResult, isNull);

      session.previous();
      expect(session.current.status, PronunciationQuestionStatus.completed);
      expect(session.current.sttResult, '1問目の結果');
    });
  });

  group('PronunciationExerciseService 取り込み済み課題の保存・削除', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('importExercises()で保存した課題はloadImported()で読み込める', () async {
      const service = PronunciationExerciseService();
      final exercise = _importedExercise(id: 'pron_imported_tsu_a');

      final added = await service.importExercises([exercise]);

      expect(added[PronunciationCategory.tsu], 1);
      final loaded = await service.loadImported(PronunciationCategory.tsu);
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'pron_imported_tsu_a');
      expect(loaded.single.source, PronunciationExerciseSource.imported);
    });

    test('IDが組み込み課題と重複する場合は取り込まれない', () async {
      const service = PronunciationExerciseService();
      final builtIn = VietnamesePronunciationBank.byCategory(
        PronunciationCategory.tsu,
      ).first;
      final duplicate = _importedExercise(id: builtIn.id, sentence: '別の文です。', reading: 'べつのぶんです。', targetExpressions: const ['べつ']);

      final added = await service.importExercises([duplicate]);

      expect(added[PronunciationCategory.tsu], 0);
      expect(await service.loadImported(PronunciationCategory.tsu), isEmpty);
    });

    test('文が組み込み課題と重複する場合は取り込まれない', () async {
      const service = PronunciationExerciseService();
      final builtIn = VietnamesePronunciationBank.byCategory(
        PronunciationCategory.tsu,
      ).first;
      final duplicate = _importedExercise(
        id: 'pron_imported_tsu_dup_sentence',
        sentence: builtIn.sentence,
        reading: 'まったくべつのよみかたです。',
        targetExpressions: const ['よみかた'],
      );

      final added = await service.importExercises([duplicate]);

      expect(added[PronunciationCategory.tsu], 0);
    });

    test('読みが組み込み課題と重複する場合は取り込まれない', () async {
      const service = PronunciationExerciseService();
      final builtIn = VietnamesePronunciationBank.byCategory(
        PronunciationCategory.tsu,
      ).first;
      final duplicate = _importedExercise(
        id: 'pron_imported_tsu_dup_reading',
        sentence: '全く別の文です。',
        reading: builtIn.reading,
        targetExpressions: const ['つ'],
      );

      final added = await service.importExercises([duplicate]);

      expect(added[PronunciationCategory.tsu], 0);
    });

    test('同じ課題を2回取り込もうとすると2回目は除外される', () async {
      const service = PronunciationExerciseService();
      final exercise = _importedExercise(id: 'pron_imported_tsu_b');

      final firstAdded = await service.importExercises([exercise]);
      final secondAdded = await service.importExercises([exercise]);

      expect(firstAdded[PronunciationCategory.tsu], 1);
      expect(secondAdded[PronunciationCategory.tsu], 0);
      expect(await service.loadImported(PronunciationCategory.tsu), hasLength(1));
    });

    test('clearImported()は指定カテゴリの取り込み済み課題だけを削除する', () async {
      const service = PronunciationExerciseService();
      await service.importExercises([
        _importedExercise(id: 'pron_imported_tsu_c'),
        _importedExercise(
          id: 'pron_imported_zrow_c',
          category: PronunciationCategory.zRow,
          sentence: '象がいます。',
          reading: 'ぞうがいます。',
          targetExpressions: const ['ぞう'],
        ),
      ]);

      await service.clearImported(PronunciationCategory.tsu);

      expect(await service.loadImported(PronunciationCategory.tsu), isEmpty);
      expect(
        await service.loadImported(PronunciationCategory.zRow),
        hasLength(1),
      );
    });

    test('組み込み25問はclearImportedの対象にならない', () async {
      const service = PronunciationExerciseService();
      for (final category in PronunciationCategory.values) {
        await service.clearImported(category);
      }

      expect(VietnamesePronunciationBank.all, hasLength(25));
      for (final category in PronunciationCategory.values) {
        expect(VietnamesePronunciationBank.byCategory(category), hasLength(5));
      }
    });

    test('loadFullPool()は組み込み25問と取り込み済み課題を合わせて返す', () async {
      const service = PronunciationExerciseService();
      await service.importExercises([_importedExercise(id: 'pron_imported_tsu_d')]);

      final pool = await service.loadFullPool();

      expect(pool, hasLength(26));
      expect(pool.where((e) => e.id == 'pron_imported_tsu_d'), hasLength(1));
    });

    test('buildSession()はpool内の取り込み済み課題も選択対象にする', () {
      final importedOnly = _importedExercise(id: 'pron_imported_tsu_only');
      final pool = [
        importedOnly,
        ...VietnamesePronunciationBank.all.where(
          (e) => e.category != PronunciationCategory.tsu,
        ),
      ];

      final session = const PronunciationExerciseService().buildSession(
        pool: pool,
        random: Random(1),
      );

      final tsuQuestions = session.questions.where(
        (q) => q.exercise.category == PronunciationCategory.tsu,
      );
      expect(tsuQuestions, hasLength(1));
      expect(tsuQuestions.single.exercise.id, 'pron_imported_tsu_only');
      expect(
        tsuQuestions.single.exercise.source,
        PronunciationExerciseSource.imported,
      );
    });
  });
}
