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
import 'package:osm_gradus/models/vocabulary_evaluation.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/views/dashboard/dashboard_screen.dart';
import 'package:osm_gradus/views/layers/scoring_history_screen.dart';
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
      '的中度・PREP行のタップでレイヤーⅣ履歴が開く', (tester) async {
    await ScoringResultStorage().save(_scoringWithAiEval());
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

    await tester.tap(find.text('的中度'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(ScoringHistoryScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ScoringHistoryScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREP'.tr(lang)));
    await tester.pumpAndSettle();
    expect(find.byType(ScoringHistoryScreen), findsOneWidget);
  });
}
