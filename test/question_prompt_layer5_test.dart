import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'question_prompt_list_test_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/launch_screen.dart';
import 'package:osm_gradus/views/layers/layer5_screen.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/pronunciation_mic_button.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';
import 'package:osm_gradus/widgets/question_prompt_nav_row.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「問題作成」にはダブルタップの機能ヒント（Step 7）が付いており、
/// GestureDetector.onDoubleTapが単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

/// 使い方シートの1行で`{{icon}}`より後ろの断片。
String _afterIcon(String key) => _t(key).split('{{icon}}').last;

/// 使い方シートの1行の先頭連番バッジを取り除いた断片。
String _withoutBadge(String key) =>
    _t(key).replaceFirst(RegExp('^[0-9]️⃣[ 　]*'), '');

const _validPronunciationSentencesJson = '''
[
  {"text": "調整をお願いします。", "reading": "ちょうせいをおねがいします。", "category": "tsu"},
  {"text": "促進していきましょう。", "reading": "そくしんしていきましょう。", "category": "sokuon"}
]
''';

Future<void> _openLayer5QuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅴ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('問題文一覧から選ぶ')));
  await tester.pumpAndSettle();
}

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

PronunciationEvaluation _buildEvaluation() => PronunciationEvaluation(
  categoryEvaluations: {
    for (final category in PronunciationCategory.values)
      category: PronunciationCategoryEvaluation(
        score: 4,
        confidence: PronunciationConfidence.medium,
        feedback: 'よくできています。',
        evidence: '評価の根拠',
      ),
  },
  summary: '全体的に発音は安定しています。',
  rawResponse: '{"raw":"chrome-ai-response"}',
  evaluationVersion: 'v2',
);

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

  testWidgets('レイヤーⅤの入口は「問題文一覧から選ぶ」「ランダム」「長文読み上げ」の3択（縦並び）', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅴ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_短文')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_長文')), findsOneWidget);
    // 縦並び（ModeListTile）であることを、3行が同じX位置から始まることで確認する。
    final xs = [
      tester.getTopLeft(find.text(_t('問題文一覧から選ぶ'))).dx,
      tester.getTopLeft(find.text(_t('レイヤーⅤ_短文'))).dx,
      tester.getTopLeft(find.text(_t('レイヤーⅤ_長文'))).dx,
    ];
    expect(xs.toSet(), hasLength(1));
  });

  testWidgets('「問題文一覧から選ぶ」で問題文一覧（進捗＝発音評点列）が開く', (tester) async {
    await _openLayer5QuestionPromptList(tester);

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('発音評点')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byType(QuestionPromptListRow), findsWidgets);
    // レイヤーⅤ未実施のため、発音評点列は「ー」になる。
    expect(find.text('ー'), findsWidgets);
  });

  testWidgets('行タップで詳細が開き、予約席レイアウト（分野の代わりに▲▼・「ランダム」と同型のマイク）を持つ（Step 5）', (
    tester,
  ) async {
    await _openLayer5QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tapQuestionPromptListRow(tester);

    expect(find.byType(DiceActionRow), findsOneWidget);
    // 分野は一覧のフィルタで絞り込めるため表示せず、同じ枠に前後移動の
    // ▲▼ボタン（QuestionPromptNavRow）を表示する。
    expect(find.byType(QuestionPromptNavRow), findsOneWidget);
    expect(find.byType(PronunciationMicButton), findsOneWidget);
    // サイコロをタップするまでは、「ランダム」と同じ案内文だけでなく問題文
    // 本文もそのまま見せる（▲▼で移動しても見た目が変わらず反応がないように
    // 見えていた回帰の修正）。この問題文専用の発音課題がまだ未生成のため、
    // 案内は「サイコロを...」ではなく「？」（問題作成）を押す案内になる。
    expect(find.text(firstRow.body), findsOneWidget);
    expect(find.text(_t('？ボタンをタップして問題を作成')), findsOneWidget);
  });

  testWidgets('サイコロをタップすると「ランダム」と同型の複数問セッションが組み立てられ、マイクに切り替わる（Step 5）', (
    tester,
  ) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    expect(state.debugArmed, isFalse);
    expect(state.debugSession.questionCount, greaterThan(1));

    await tester.tap(find.byType(PronunciationMicButton));
    await tester.pump();

    expect(state.debugArmed, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets(
    '「問題作成」タップでGoogle送信の同意ダイアログが開き、貼り付けで問題文専用の発音練習文が保存され出題される（Step 6）',
    (tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _openLayer5QuestionPromptList(tester);
      final firstRow = tester.widget<QuestionPromptListRow>(
        find.byType(QuestionPromptListRow).first,
      );
      await tapQuestionPromptListRow(tester);

      final iconBefore = tester.widget<Icon>(find.byIcon(Icons.quiz_outlined));
      expect(iconBefore.color, isNot(Colors.orange));

      await tester.tap(find.byIcon(Icons.quiz_outlined));
      await tester.pump(_tapConfirmWait);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await Clipboard.setData(
        const ClipboardData(text: _validPronunciationSentencesJson),
      );
      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // 貼り付け完了後はアイコンが「問題作成」アイコンに戻り、色だけ橙になる
      // （レイヤーⅠの単語抽出と同じ配色）。
      final iconAfter = tester.widget<Icon>(find.byIcon(Icons.quiz_outlined));
      expect(iconAfter.color, Colors.orange);

      final all = await QuestionPromptService().loadAll();
      final updated = all.firstWhere((p) => p.body == firstRow.body);
      expect(updated.pronunciationSentences, hasLength(2));
      expect(updated.pronunciationSentences.first.text, '調整をお願いします。');
      expect(
        updated.pronunciationSentences.first.category,
        PronunciationCategory.tsu,
      );
      expect(
        updated.pronunciationSentences.last.category,
        PronunciationCategory.sokuon,
      );

      // 生成された10問（このテストでは2問）が、そのまま出題プールになる。
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      expect(state.debugSession.questionCount, 2);

      // その生成済み短文で発音テスト→スコア保存まで通ることを確認する。
      await state.debugApplyEvaluation(_buildEvaluation());
      await tester.pumpAndSettle();
      final scored = (await QuestionPromptService().loadAll()).firstWhere(
        (p) => p.body == firstRow.body,
      );
      expect(scored.hasPronunciationScore, isTrue);
    },
  );

  testWidgets('発音評価を問題文に反映すると、一覧の進捗にも反映される', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tapQuestionPromptListRow(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await state.debugApplyEvaluation(_buildEvaluation());
    await tester.pumpAndSettle();

    final all = await QuestionPromptService().loadAll();
    final updated = all.firstWhere((p) => p.body == firstRow.body);
    expect(updated.hasPronunciationScore, isTrue);
    expect(
      updated.pronunciationScores.length,
      PronunciationCategory.values.length,
    );
  });

  testWidgets('AI評価が届くと「総評」バッジが出て、タップで総評画面へ遷移する', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    expect(find.byIcon(Icons.fact_check_rounded), findsNothing);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await state.debugApplyEvaluation(_buildEvaluation());
    await tester.pumpAndSettle();

    // AI評価が届いたので「総評」バッジが出る（MainShellがonGoToSummaryを渡す）。
    expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fact_check_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 総評画面（レイヤー別の結果カード）へ遷移する。
    expect(find.text(_t('レイヤーⅠタイトル')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤタイトル')), findsOneWidget);
  });

  testWidgets('詳細画面の常設ヘッダー「Ⅴ」をタップすると、3択画面ではなく問題文一覧へ直接飛ぶ（回帰）', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    await tester.tap(find.text('Ⅴ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_短文')), findsNothing);
  });

  testWidgets('詳細画面の常設ヘッダーを長押しすると、一覧ではなくスタート画面へジャンプする', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    await tester.longPress(find.text('Ⅴ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(LaunchScreen), findsOneWidget);
  });

  testWidgets('問題文経路の「＋」長押し使い方に問題作成と総評が含まれ、録音モード行は出ない', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅤ_問題文_使い方_問題作成'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅤ_問題文_使い方_総評'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅤ_使い方_録音モード'), findRichText: true),
      findsNothing,
    );
  });

  testWidgets('録音中（isBusy）は▲▼ボタン自体が隠れており、前後の問題文へ移動できない', (tester) async {
    await _openLayer5QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    state.debugForceRecordingStatus();
    await tester.pump();
    expect(state.isBusy, isTrue);

    // 進行中の10問セッションの間（サイコロタップ後〜採点まで）は、進行中の
    // 録音を失わせないよう▲▼ボタンごと隠す（枠だけ確保し、タップも通さない）。
    final navVisibility = tester.widget<Visibility>(
      find
          .ancestor(
            of: find.byType(QuestionPromptNavRow),
            matching: find.byType(Visibility),
          )
          .first,
    );
    expect(navVisibility.visible, isFalse);
  });
}
