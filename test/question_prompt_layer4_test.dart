import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer4_screen.dart';
import 'package:osm_gradus/widgets/category_select_field.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/layer_numeral_badge.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「V」バッジ等、ダブルタップの機能ヒントが付いたボタン（Step 7）は
/// GestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

Future<void> _openLayer4QuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅳ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('問題文一覧から選ぶ')));
  await tester.pumpAndSettle();
}

SavedScoringResult _buildEvaluatedResult() {
  final now = DateTime.now();
  return SavedScoringResult(
    id: 'test_result_1',
    createdAt: now,
    result: ScoringResult(
      transcriptChunks: const [],
      fullTranscript: 'テストの回答です。',
      keigo: const KeigoAnalysis(categories: [], varietyScore: 0),
      complexity: const SentenceComplexityAnalysis(
        totalUnits: 1,
        complexUnitCount: 0,
        complexityRatio: 0,
      ),
      fluency: FluencyAnalysis.unavailable(allottedSeconds: 45),
      generatedAt: now,
    ),
    prepStars: 4,
    hitStars: 5,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    audioHandler = PodcastAudioHandler(PodcastLibraryService());
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
  });

  testWidgets('レイヤーⅣの入口は「問題文一覧から選ぶ」「ランダム」の2択', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
  });

  testWidgets('「ランダム」で既存のサイコロ・タイマー・録音画面が開く', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();

    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.byType(CategorySelectField), findsOneWidget);
  });

  testWidgets('「問題文一覧から選ぶ」で問題文一覧（進捗＝JSST評点列）が開く', (tester) async {
    await _openLayer4QuestionPromptList(tester);

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('JSST評点')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byType(QuestionPromptListRow), findsWidgets);
    // レイヤーⅣ未実施のため、JSST評点列は「ー」になる。
    expect(find.text('ー'), findsWidgets);
  });

  testWidgets('行タップで詳細が開き、予約席レイアウト（分野非表示・開始ボタン・本文）を持つ', (tester) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(DiceActionRow), findsOneWidget);
    // 一覧から選ぶモードでは、分野は既に固定されているため表示せず、
    // 同じ枠に前後移動の▲▼ボタン（QuestionPromptNavRow）を表示する。
    expect(find.byType(CategorySelectField), findsNothing);
    // 問題文が1件しかないと前後どちらも無いため、両方隠れていることもある。
    // サイコロの代わりに「開始」アイコンで、抽選前から問題文が見えている。
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsNothing);
    expect(find.byType(LayerNumeralBadge), findsNothing);
  });

  testWidgets('JSST採点結果が問題文エンティティのjsstScoreに反映される', (tester) async {
    await _openLayer4QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    await state.debugPersistScoreToPrompt(jsstScore: 3);
    await tester.pumpAndSettle();

    final all = await QuestionPromptService().loadAll();
    final updated = all.firstWhere((p) => p.body == firstRow.body);
    expect(updated.jsstScore, 3);
  });

  testWidgets('AI評価（PREP・的中度）が届くと紙飛行機の代わりに「V」バッジが出る', (tester) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(LayerNumeralBadge), findsNothing);

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    state.debugSetEvaluatedResult(_buildEvaluatedResult());
    await tester.pumpAndSettle();

    expect(find.byType(LayerNumeralBadge), findsOneWidget);

    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 詳細画面が閉じてレイヤーⅤへ切り替わった
    // （Step 6未実装のため、この時点ではレイヤーⅤの既定表示になる）。
    expect(find.byType(Layer4Screen), findsNothing);
  });

  testWidgets('AI貼り付け待ちなど（isBusy）の間は▼ボタンで前後の問題文へ移動できず、案内が出る', (tester) async {
    await _openLayer4QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();
    expect(find.text(firstRow.body), findsOneWidget);

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    expect(state.isBusy, isFalse);
    state.chromeAiAwaitingPaste = true;
    expect(state.isBusy, isTrue);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 進行中の状態を失わせないよう、問題文は切り替わらず案内だけが出る。
    expect(find.text(firstRow.body), findsOneWidget);
    expect(find.text(_t('録音中は移動できません')), findsOneWidget);
  });
}
