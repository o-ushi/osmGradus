import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/models/vocabulary_evaluation.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';
import 'package:osm_gradus/services/thinking_matrix_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/views/dashboard/dashboard_screen.dart';
import 'package:osm_gradus/views/layers/pronunciation_check_detail_screen.dart';
import 'package:osm_gradus/views/layers/pronunciation_history_screen.dart';
import 'package:osm_gradus/views/layers/scoring_history_screen.dart';
import 'package:osm_gradus/views/layers/scoring_result_screen.dart';
import 'package:osm_gradus/views/layers/vocabulary_check_detail_screen.dart';
import 'package:osm_gradus/views/layers/vocabulary_check_history_screen.dart';
import 'package:osm_gradus/widgets/genki_transport_row.dart';

SavedPronunciationCheck _pronunciation({required int score}) {
  final now = DateTime(2026, 2, 1);
  final evaluation = PronunciationEvaluation(
    categoryEvaluations: {
      for (final category in PronunciationCategory.values)
        category: PronunciationCategoryEvaluation(
          score: score,
          confidence: PronunciationConfidence.medium,
          feedback: 'ok',
          evidence: 'evidence',
        ),
    },
    summary: 'summary',
    languageCode: 'ja',
    rawResponse: '{}',
    evaluationVersion: 'v2',
  );
  return SavedPronunciationCheck(
    id: 'p_$score',
    createdAt: now,
    transcript: '',
    sessionId: 'session',
    questions: const [],
    evaluation: evaluation,
  );
}

SavedScoringResult _scoringWithAiEval() {
  final started = DateTime(2026, 1, 1, 10);
  const text = '本日はご多忙のところお集まりいただきまして誠にありがとうございます。今後ともよろしくお願い申し上げます。';
  final result = ScoringResult(
    transcriptChunks: [TranscriptChunk(text: text, recognizedAt: started)],
    fullTranscript: text,
    keigo: const KeigoAnalysis(
      varietyScore: 2,
      categories: [
        KeigoCategoryResult(category: 'teineigo', matchedExpressions: {'です'}),
        KeigoCategoryResult(category: 'sonkeigo', matchedExpressions: {'いただき'}),
        KeigoCategoryResult(category: 'kenjougo', matchedExpressions: {}),
      ],
    ),
    complexity: const SentenceComplexityAnalysis(
      totalUnits: 4,
      complexUnitCount: 2,
      complexityRatio: 0.5,
    ),
    fluency: FluencyAnalysis(
      allottedSeconds: 45,
      capturedSeconds: 40,
      timeToFirstSpeechSeconds: 1,
      estimatedSpeechSeconds: 30,
      estimatedSilenceSeconds: 10,
      silenceRatio: 0.2,
      timeUtilization: 0.7,
      spokenCharacterCount: text.length,
      charactersPerAllottedMinute: 120,
      longPauseCount: 0,
      referenceLevel: 4,
    ),
    session: SpeechSessionContext(
      allottedSeconds: 45,
      startedAt: started,
      endedAt: started.add(const Duration(seconds: 45)),
    ),
  );
  return SavedScoringResult(
    id: 'scoring_1',
    createdAt: started,
    result: result,
  ).withAiEvaluation(
    prepStars: 4,
    hitStars: 3,
    prepAdvice: 'prep advice',
    hitAdvice: 'hit advice',
  );
}

SavedVocabularyCheck _vocabulary({required int score}) {
  return SavedVocabularyCheck(
    id: 'vocab_1',
    createdAt: DateTime(2026, 3, 1),
    sessionId: 'session',
    questions: const [],
    evaluation: VocabularyEvaluation(
      overallScore: score,
      questionEvaluations: const [],
      rawResponse: '{}',
      evaluationVersion: 'v1',
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 判定材料が1件も無いと紙飛行機ボタン自体が出ないため、1件以上ある状態を作る。
    await PronunciationCheckStorage().save(_pronunciation(score: 5));
  });

  testWidgets('紙飛行機ボタンをタップすると、Google送信の同意ダイアログが開く（二重ガード回帰）', (tester) async {
    // chromeAiSend自体がchromeAiActionInFlightの二重タップ防止を内部で
    // 行うため、呼び出し側（_sendToChromeAi）が同じフラグを事前に立てて
    // いると、chromeAiSend冒頭のガードに引っかかって常に即returnし、
    // タップしても何も起きなくなる（実際に発生した回帰）。
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    final sendIcon = find.descendant(
      of: find.byType(GenkiTransportRow),
      matching: find.byIcon(Icons.send_rounded),
    );
    expect(sendIcon, findsOneWidget);

    await tester.tap(sendIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('判定カードにJSST・的中度・PREP・語彙・発音の5行と総合が表示され、'
      'タップ＝最新1件の詳細、長押し＝一覧が開く（Step 8）', (tester) async {
    final scoring = _scoringWithAiEval();
    await ScoringResultStorage().save(scoring);
    await VocabularyCheckStorage().save(_vocabulary(score: 2));

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    final lang = appSettings.language;
    expect(find.text('総合'.tr(lang)), findsOneWidget);
    expect(find.text('JSST'.tr(lang)), findsOneWidget);
    expect(find.text('的中度'.tr(lang)), findsOneWidget);
    expect(find.text('PREP'.tr(lang)), findsOneWidget);
    expect(find.text('語彙'.tr(lang)), findsOneWidget);
    expect(find.text('発音'.tr(lang)), findsOneWidget);
    // 的中度=3.0、PREP=4.0（1件のみなのでそのまま平均になる）。
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);

    // タップ＝最新1件の採点結果詳細（的中度・PREP・JSSTは同じストレージ）。
    await tester.tap(find.text('的中度'.tr(lang)));
    await tester.pumpAndSettle();
    final scoringResultScreen = tester.widget<ScoringResultScreen>(
      find.byType(ScoringResultScreen),
    );
    expect(scoringResultScreen.result.id, scoring.id);

    Navigator.of(tester.element(find.byType(ScoringResultScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREP'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(ScoringResultScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ScoringResultScreen))).pop();
    await tester.pumpAndSettle();

    // 長押し＝一覧画面。
    await tester.longPress(find.text('的中度'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(ScoringHistoryScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ScoringHistoryScreen))).pop();
    await tester.pumpAndSettle();

    // 語彙行：タップ＝最新1件の詳細、長押し＝一覧。
    await tester.tap(find.text('語彙'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(VocabularyCheckDetailScreen), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(VocabularyCheckDetailScreen)),
    ).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('語彙'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(VocabularyCheckHistoryScreen), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(VocabularyCheckHistoryScreen)),
    ).pop();
    await tester.pumpAndSettle();

    // 発音行：タップ＝最新1件の詳細、長押し＝一覧。
    await tester.tap(find.text('発音'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(PronunciationCheckDetailScreen), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(PronunciationCheckDetailScreen)),
    ).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('発音'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(PronunciationHistoryScreen), findsOneWidget);
  });

  group('Step 3〜4: 総合／テスト総合／拡充度総合の3段判定＋25マス拡充度', () {
    testWidgets('判定カードに総合／テスト総合／拡充度総合の3行と、25マス拡充度'
        '（日常/ビジネス/シチュエーション/トータル）が見える', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pumpAndSettle();

      final lang = appSettings.language;
      expect(find.text('総合'.tr(lang)), findsOneWidget);
      expect(find.text('テスト総合'.tr(lang)), findsOneWidget);
      expect(find.text('拡充度総合'.tr(lang)), findsOneWidget);
      expect(find.text('（ー）'), findsOneWidget);
      expect(find.text('（0.0%）'), findsOneWidget);

      final overallDx = tester
          .getTopLeft(find.byKey(const Key('dashboard-grade-letter-overall')))
          .dx;
      expect(
        tester
            .getTopLeft(find.byKey(const Key('dashboard-grade-letter-test')))
            .dx,
        overallDx,
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const Key('dashboard-grade-letter-expansion')),
            )
            .dx,
        overallDx,
      );
      expect(find.text('テスト結果'.tr(lang)), findsOneWidget);
      expect(find.text('25マス拡充度'.tr(lang)), findsOneWidget);
      expect(find.text('日常'.tr(lang)), findsOneWidget);
      expect(find.text('ビジネス'.tr(lang)), findsOneWidget);
      expect(find.text('シチュエーション'.tr(lang)), findsOneWidget);
      expect(find.text('トータル'.tr(lang)), findsOneWidget);

      // クリーンなprefsのままダッシュボードを開いたので、25マスは未着手＝
      // 全カテゴリ0.0%（Step 1のensureSystemPresetsは呼ばれるが空セット）。
      expect(find.text('0.0%'), findsWidgets);
    });

    testWidgets('ダッシュボード読込時にensureSystemPresetsが走り、'
        '日常・ビジネス・シチュエーションの3セットが揃う（Step 1連携）', (tester) async {
      expect(await ThinkingMatrixService().loadAll(), isEmpty);

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pumpAndSettle();

      final sets = await ThinkingMatrixService().loadAll();
      expect(
        sets.map((s) => s.id).toSet(),
        ThinkingMatrixService.systemSetIds.values.toSet(),
      );
    });

    testWidgets('25マスの日常セットに1マスだけキーワードがあると、'
        '拡充度の日常%・トータル%に反映される', (tester) async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();
      final daily = (await service.loadAll()).firstWhere(
        (s) => s.id == ThinkingMatrixService.systemSetIds[TopicCategory.daily],
      );
      await service.upsertCellLayer2(
        setId: daily.id,
        themeId: daily.themes.first.id,
        columnId: daily.columns.first.id,
        keyword: 'テストキーワード',
      );

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pumpAndSettle();

      // (1/3)/25*100 ≈ 1.3%、(1/3)/65*100 ≈ 0.5%（Step 2で固定済みの計算式）。
      expect(find.text('1.3%'), findsOneWidget);
      expect(find.text('0.5%'), findsOneWidget);
    });
  });
}
