import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/layer4_prompt_reveal_mode.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/theme/app_colors.dart';
import 'package:osm_gradus/views/layers/layer4_screen.dart';
import 'package:osm_gradus/widgets/category_select_field.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/layer_numeral_badge.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';
import 'package:osm_gradus/widgets/topic_speaker_timer_button.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 使い方シートの1行の先頭連番バッジ（1️⃣など）を取り除いた断片
/// （[LayerHelpLine]が描画時にバッジを別ウィジェットへ分離するため、
/// test/layers_test.dartの`_withoutBadge`と同じ照合方法）。
String _withoutBadge(String key) =>
    _t(key).replaceFirst(RegExp('^[0-9]️⃣[ 　]*'), '');

/// `{{icon}}`を含む行（例：「{{icon}} ボタンで問題文を表示」）はアイコンが
/// 別ウィジェットに分離され、後半のテキストだけが単独のTextとして描画
/// される（test/layers_test.dartの`_afterIcon`と同じ照合方法）。
String _afterIcon(String key) => _t(key).split('{{icon}}').last;

/// 「V」バッジ等、ダブルタップの機能ヒントが付いたボタン（Step 7）は
/// GestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

/// 解答例の妥当性チェックを通る長さのプレーンテキスト
/// （[test/question_prompt_layer2_test.dart]と同型）。
const _sampleAnswerPasteText = '電話ではまず結論から簡潔に話すことが大切です。相手の時間を意識して用件をまとめましょう。';

/// [test/question_prompt_layer2_test.dart]と同型のクリップボードモック。
void _mockClipboard(WidgetTester tester) {
  var clipboardText = '';
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String? ?? '';
          return null;
        default:
          return null;
      }
    },
  );
}

/// [test/question_prompt_layer2_test.dart]と同型のurl_launcherフェイク。
class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

/// 同意ダイアログの「同意してGoogleへ送信」を確定し、直後の
/// 「コピー案内」SnackBarを明示的に消してから返す
/// （[test/question_prompt_layer2_test.dart]の`_confirmChromeAiSend`と同型）。
Future<void> _confirmChromeAiSend(WidgetTester tester) async {
  await tester.tap(find.text(_t('同意してGoogleへ送信')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .clearSnackBars();
  await tester.pumpAndSettle();
}

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

/// [_buildEvaluatedResult]と違い、prepStars/hitStarsを付けない＝JSST採点済み
/// だがまだAI評価（PREP・的中度）は届いていない状態
/// （`_showSendPrepHit`がtrueになり、紙飛行機の「送信」をタップできる）。
SavedScoringResult _buildScoredResult() {
  final now = DateTime.now();
  return SavedScoringResult(
    id: 'test_result_scored',
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

  testWidgets('ランダム：カテゴリ選択に「ランダム」は出ない（Ⅱと同じ問題文プール制約、Step 4）', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();

    await tester.tap(find.text(_t('日常')));
    await tester.pumpAndSettle();

    // シチュエーションは既存どおり「15+60秒」モード専用（既定は45秒なので
    // ここでは出ない）。Step 4で変わるのは「ランダム」が選べなくなる点だけ。
    expect(find.text(_t('ビジネス')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsNothing);
  });

  testWidgets('ランダム：サイコロは問題文プールから抽選し、抽選前は解答例アイコンが出ず、抽選後だけ出る（Step 4）', (
    tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();

    // 未抽選では理由枠（解答例）の実体アイコンが無い（他レイヤーと同じ
    // 予約席のまま）。
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    final drawn = state.debugDrawnPrompt;
    expect(drawn, isNotNull);

    // 抽選元がQuestionPromptService（Ⅱと同じプール）であること。
    final all = await QuestionPromptService().loadAll();
    expect(all.map((p) => p.id), contains(drawn!.id));

    // 抽選後は解答例アイコンが出る（未取得＝白）。
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      isNot(Colors.orange),
    );
  });

  testWidgets('ランダム：抽選済みの問題文に解答例を保存すると、Ⅱと同じプールに反映される（Step 4）', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    final drawnId = state.debugDrawnPrompt!.id;

    await state.saveSampleAnswer(_sampleAnswerPasteText);
    await tester.pumpAndSettle();

    final updated = await QuestionPromptService().loadById(drawnId);
    expect(updated?.sampleAnswer, _sampleAnswerPasteText);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );
  });

  testWidgets('ランダム：JSST採点結果が抽選済み問題文のjsstScoreに反映される（Step 4）', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    final drawnId = state.debugDrawnPrompt!.id;

    await state.debugPersistScoreToPrompt(jsstScore: 3);
    await tester.pumpAndSettle();

    final updated = await QuestionPromptService().loadById(drawnId);
    expect(updated?.jsstScore, 3);
  });

  testWidgets('ランダム：再抽選すると、前の問題の解答例待ちが残らない（Step 4）', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    expect(state.debugDrawnPrompt, isNotNull);
    state.chromeAiAwaitingPaste = true;

    // 実機のTTS読み上げ完了を待たないタップ経由の他テストと同じく、
    // drawAndSpeak()自体は完了を待たず（内部のspeak()がテスト環境では
    // 完了しないため）、状態が同期的に更新される分だけpumpする。
    unawaited(state.drawAndSpeak());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.debugDrawnPrompt, isNotNull);
    expect(state.chromeAiAwaitingPaste, isFalse);
  });

  group('サイコロモード：ラピッド／タートル（Step 3）', () {
    // 実際の既定値（タートル。test/layer4_prompt_reveal_mode_test.dart参照）とは
    // 無関係に、このグループのテストごとの起点をラピッドに固定する
    // （appSettingsはファイル全体でsetUpAllから使い回す1インスタンスのため、
    // 前のテストで切り替えたモードが漏れないようにするための決め打ち）。
    setUp(() {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid;
    });

    testWidgets('ランダム・ラピッド：サイコロは橙色で、1タップで問題文表示と読み上げが同時に始まる', (
      tester,
    ) async {
      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.casino)).color,
        AppColors.current.cardAccent,
      );

      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.buttonPhase, TopicSpeakerTimerPhase.speaking);
      expect(state.drawnTopic, isNotNull);
    });

    testWidgets('ランダム・タートル：サイコロは通常色。1タップ目は問題文だけ表示し（アイコンがスピーカーに変わる）、'
        '2タップ目（スピーカー）で表示済みの問題文をそのまま読み上げる', (tester) async {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.casino)).color,
        isNot(AppColors.current.cardAccent),
      );

      // 1タップ目：問題文だけ表示。読み上げはまだ始めない（idleのまま）。
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.buttonPhase, TopicSpeakerTimerPhase.idle);
      final previewedTopic = state.drawnTopic;
      expect(previewedTopic, isNotNull);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.casino), findsNothing);

      // 2タップ目（スピーカー）：表示済みの問題文をそのまま読み上げ開始する
      // （抽選をやり直さない）。
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(state.buttonPhase, TopicSpeakerTimerPhase.speaking);
      expect(state.drawnTopic, previewedTopic);
    });

    testWidgets('一覧から選ぶ・タートル：開始アイコンの1タップ目は表示のみ、2タップ目で読み上げる', (tester) async {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await _openLayer4QuestionPromptList(tester);
      await tester.tap(find.byType(QuestionPromptListRow).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.buttonPhase, TopicSpeakerTimerPhase.idle);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(state.buttonPhase, TopicSpeakerTimerPhase.speaking);
    });

    testWidgets('サイコロ長押しでラピッド→タートルに切り替わり、永続化されSnackBarが出る（Step 4）', (
      tester,
    ) async {
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      expect(appSettings.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);

      await tester.longPress(find.byIcon(Icons.casino));
      await tester.pump();

      expect(appSettings.layer4PromptRevealMode, Layer4PromptRevealMode.turtle);
      // 端末内に永続化：AppPreferences側からも読み戻せる（再起動を模す）。
      expect(
        appPreferences.layer4PromptRevealMode,
        Layer4PromptRevealMode.turtle,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.casino)).color,
        isNot(AppColors.current.cardAccent),
      );
      expect(
        find.text(
          _t('レイヤーⅣ_モード_切替').replaceFirst('{{mode}}', _t('レイヤーⅣ_モード_タートル')),
        ),
        findsOneWidget,
      );

      // もう一度長押しするとラピッドへ戻る。
      await tester.longPress(find.byIcon(Icons.casino));
      await tester.pump();
      expect(appSettings.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.casino)).color,
        AppColors.current.cardAccent,
      );
    });

    testWidgets('読み上げ中は長押しが無効（モードは変わらない、Step 4）', (tester) async {
      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.buttonPhase, TopicSpeakerTimerPhase.speaking);

      await tester.longPress(find.byIcon(Icons.volume_up));
      await tester.pump();

      expect(appSettings.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);
    });

    testWidgets('タートルで問題文表示済み（読み上げ待ち）のまま長押しでラピッドへ切り替えても、'
        '表示済みの問題文をそのまま読み上げる（再抽選しない、Step 4）', (tester) async {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      // 1タップ目：問題文だけ表示。
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.buttonPhase, TopicSpeakerTimerPhase.idle);
      final previewedTopic = state.drawnTopic;
      expect(previewedTopic, isNotNull);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // 表示待ちのまま長押しでラピッドへ切り替える。
      await tester.longPress(find.byIcon(Icons.volume_up));
      await tester.pump();
      expect(appSettings.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);
      // 表示済みの問題文は保持されたまま（再抽選されていない）。
      expect(state.drawnTopic, previewedTopic);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // タップで、表示済みの問題文をそのまま読み上げ開始する（再抽選しない）。
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(state.buttonPhase, TopicSpeakerTimerPhase.speaking);
      expect(state.drawnTopic, previewedTopic);
    });

    testWidgets('ランダム・ラピッド：使い方シートにモード切替案内が載り、タートル手順は出ない（Step 9）', (
      tester,
    ) async {
      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_t('操作方法')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_使い方_サイコロ'), findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_t('レイヤーⅣ_使い方_モード切替')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_使い方_サイコロ_タートル'), findRichText: true),
        findsNothing,
      );
    });

    testWidgets('ランダム・タートル：使い方シートに2タップ手順とモード切替案内が載る（Step 9）', (tester) async {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await tester.pumpWidget(const OsmGradusApp());
      await tester.tap(find.text('Tầng I'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ⅳ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('ランダム')));
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_t('操作方法')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_使い方_サイコロ_タートル'), findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_t('レイヤーⅣ_使い方_モード切替')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_使い方_サイコロ'), findRichText: true),
        findsNothing,
      );
    });

    testWidgets('一覧から選ぶ・タートル：使い方シートに2タップ手順とモード切替案内が載る（Step 9）', (tester) async {
      appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      addTearDown(
        () => appSettings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid,
      );

      await _openLayer4QuestionPromptList(tester);
      await tester.tap(find.byType(QuestionPromptListRow).first);
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_t('操作方法')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_問題文_使い方_開始_タートル'), findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_t('レイヤーⅣ_使い方_モード切替')), findsOneWidget);
      expect(
        find.text(_afterIcon('レイヤーⅣ_問題文_使い方_開始'), findRichText: true),
        findsNothing,
      );
    });
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

  testWidgets('「＋」長押しの使い方シートに、解答例の作成・閲覧の案内がある', (tester) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅣ_問題文_使い方_解答例'), findRichText: true),
      findsOneWidget,
    );
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

  testWidgets('解答例が空の問題文でも「理由」枠（解答例アイコン）は出る。タップで同意ダイアログが出てキャンセルできる（Step 3）', (
    tester,
  ) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    // 一覧から選ぶ経路はⅡ一覧詳細と同じく常時表示（未取得でも新規作成できる）。
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
    expect(icon.color, isNot(Colors.orange));

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsOneWidget);
    await tester.tap(find.text(_t('キャンセル')));
    await tester.pumpAndSettle();
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);
  });

  testWidgets('解答例アイコンをダブルタップすると機能ヒントが出て、単タップの動作（同意ダイアログ）は実行されない（Ⅱと同型）', (
    tester,
  ) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    final icon = find.byIcon(Icons.menu_book_rounded);
    await tester.tap(icon);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(icon);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining(_t('レイヤーⅡ_解答例_取得')), findsWidgets);
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);
  });

  testWidgets('解答例：同意→Chrome起動→貼り付けで保存され、橙アイコンになり再表示でも残る（Step 3）', (
    tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    await _confirmChromeAiSend(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);

    // 送信後は貼り付け待ちの緑アイコンに切り替わる（Ⅱと同型）。
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.content_paste_go_rounded)).color,
      kPasteReadyColor,
    );

    await Clipboard.setData(const ClipboardData(text: _sampleAnswerPasteText));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
    expect(icon.color, Colors.orange);

    final all = await QuestionPromptService().loadAll();
    expect(
      all.where((p) => p.sampleAnswer == _sampleAnswerPasteText),
      hasLength(1),
    );

    // 画面を閉じて開き直しても残る。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );
  });

  testWidgets('解答例が取得済みの問題文は、タップで同意ダイアログではなく読み取り専用シートで表示される（編集不可）', (
    tester,
  ) async {
    await _openLayer4QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );

    final service = QuestionPromptService();
    final all = await service.loadAll();
    final target = all.firstWhere((p) => p.body == firstRow.body);
    final sampleAnswer =
        '[質問]\n${target.body}\n[日本語]\n模範解答本文です。\n[Romaji]\n'
        'Mohan kaitou honbun desu.';
    await service.update(target.copyWith(sampleAnswer: sampleAnswer));

    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    final icon = find.byIcon(Icons.menu_book_rounded);
    expect(icon, findsOneWidget);
    expect(tester.widget<Icon>(icon).color, Colors.orange);

    await tester.tap(icon);
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 読み取り専用シートに全文が表示される（同意ダイアログは出ない）。
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);
    expect(find.text(_t('解答例')), findsWidgets);
    expect(find.text(sampleAnswer), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
  });

  testWidgets('▲▼で問題文を切り替えると、解答例アイコンの色（取得済み橙／未取得白）が新しい問題文に追従する', (
    tester,
  ) async {
    await _openLayer4QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );

    final service = QuestionPromptService();
    final all = await service.loadAll();
    final target = all.firstWhere((p) => p.body == firstRow.body);
    await service.update(
      target.copyWith(sampleAnswer: '[質問]\n${target.body}\n[日本語]\n模範解答。'),
    );

    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    // 1件目（解答例あり）は橙。
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );

    // ▼で2件目（解答例なし）へ移動すると白に戻る（アイコン自体は消えない）。
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      isNot(Colors.orange),
    );

    // ▲で1件目へ戻ると再び橙になる（別問題の解答例が残らないこと）。
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );
  });

  testWidgets('PREP・的中度（紙飛行機）の貼り付け待ち中は、解答例アイコンをタップしても誤って貼り付けを走らせない（AI往復の衝突）', (
    tester,
  ) async {
    await _openLayer4QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
    state.debugSetEvaluatedResult(_buildScoredResult());
    await tester.pumpAndSettle();

    // 紙飛行機を送信して貼り付け待ちにする（同意→送信）。
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    await _confirmChromeAiSend(tester);
    expect(state.chromeAiAwaitingPaste, isTrue);

    // 解答例アイコン（未取得＝白）はまだ見えているが、紙飛行機待ち中の
    // タップは無視され、クリップボードを解答例として保存してしまわない。
    await Clipboard.setData(const ClipboardData(text: _sampleAnswerPasteText));
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    final all = await QuestionPromptService().loadAll();
    expect(all.where((p) => p.sampleAnswer.isNotEmpty), isEmpty);
    // 紙飛行機側の貼り付け待ちも誤って解除されていない。
    expect(state.chromeAiAwaitingPaste, isTrue);
  });

  testWidgets(
    '解答例の貼り付け待ち中は、紙飛行機（PREP・的中度）をタップしても誤って貼り付けを走らせない（AI往復の衝突・逆方向、Step 6）',
    (tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _openLayer4QuestionPromptList(tester);
      await tester.tap(find.byType(QuestionPromptListRow).first);
      await tester.pumpAndSettle();

      // 解答例を送信して貼り付け待ちにする（同意→送信）。
      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pumpAndSettle();
      await _confirmChromeAiSend(tester);

      final state = tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
      expect(state.chromeAiAwaitingPaste, isTrue);

      // JSST採点済み（未評価）の結果を与え、紙飛行機の「送信」を表示させる。
      state.debugSetEvaluatedResult(_buildScoredResult());
      await tester.pumpAndSettle();

      // 紙飛行機（送信）をタップしても、解答例側の貼り付け待ち中は無視され、
      // クリップボードをPREP・的中度として誤って解析・保存してしまわない。
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pumpAndSettle();

      expect(state.debugLastResult?.hasAiEvaluation ?? false, isFalse);
      // 解答例側の貼り付け待ちも誤って解除されていない。
      expect(state.chromeAiAwaitingPaste, isTrue);
    },
  );
}
