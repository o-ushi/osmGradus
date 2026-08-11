import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/pronunciation_practice_session.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/privacy_consent_service.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer5_screen.dart';
import 'package:osm_gradus/views/layers/pronunciation_check_detail_screen.dart';
import 'package:osm_gradus/views/layers/pronunciation_history_screen.dart';
import 'package:osm_gradus/widgets/pronunciation_exercise_card.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);
String _tFmt(String key, List<String> args) => key.trFmt(_lang, args);

/// 「送信」「貼り付け」等、ダブルタップの機能ヒントが付いたボタン（Step 7）
/// はGestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

/// tsu=1点（最低）、sokuon=2点（次点）で、5カテゴリすべて異なるスコアの
/// 妥当なChrome AI回答例。「改善の重点」は「つ」になる想定。
const _validEvaluationJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 1, "confidence": "medium", "feedbackJa": "「つ」の発音が弱いです。", "feedbackVi": "Âm \\"つ\\" hơi yếu.", "evidence": "期待:つくえ / 認識:すくえ"},
    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "良好です。", "feedbackVi": "Tốt.", "evidence": "期待:みず / 認識:みず"},
    "rRow": {"score": 3, "confidence": "medium", "feedbackJa": "普通です。", "feedbackVi": "Bình thường.", "evidence": "期待:りんご / 認識:りんご"},
    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "完璧です。", "feedbackVi": "Hoàn hảo.", "evidence": "期待:くうき / 認識:くうき"},
    "sokuon": {"score": 2, "confidence": "low", "feedbackJa": "促音が短いです。", "feedbackVi": "Âm ngắt hơi ngắn.", "evidence": "期待:きって / 認識:きて"}
  },
  "summaryJa": "全体的に良く練習できています。",
  "summaryVi": "Nhìn chung bạn đã luyện tập tốt."
}''';

/// v2形式（feedback/summaryを単一言語のみで書く新スキーマ）の英語回答例。
const _validEnglishEvaluationJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 1, "confidence": "medium", "feedback": "The tsu sound is a bit weak.", "evidence": "expected:tsukue / recognized:sukue"},
    "zRow": {"score": 4, "confidence": "high", "feedback": "Good.", "evidence": "expected:mizu / recognized:mizu"},
    "rRow": {"score": 3, "confidence": "medium", "feedback": "Average.", "evidence": "expected:ringo / recognized:ringo"},
    "longVowel": {"score": 5, "confidence": "high", "feedback": "Perfect.", "evidence": "expected:kuuki / recognized:kuuki"},
    "sokuon": {"score": 2, "confidence": "low", "feedback": "The sokuon is short.", "evidence": "expected:kitte / recognized:kite"}
  },
  "summary": "Overall, you are practicing well."
}''';

/// クリップボードをテスト内で完結するインメモリの偽実装に差し替える
/// （flutter_test既定のクリップボード処理はFakeAsync下でgetDataが
/// 正しく往復しないため）。
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

/// レイヤーⅤの「評価を送信」で使う外部ブラウザ起動を、実プラットフォーム
/// チャンネルなしで検証するためのフェイク実装。
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

/// [Layer5Screen]単体を最小限のMaterialApp（SnackBar/Dialog表示用にScaffold付き）
/// で描画する。レイヤーⅠのシェイク検出などフルアプリ特有の副作用を避けるため、
/// フルアプリ（[OsmGradusApp]）は経由しない。
Future<void> _pumpLayer5(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer5Screen())),
  );
  await tester.pump();
}

/// デバッグフックで10問すべてを「回答済み」にする（実機のネイティブ録音・
/// STTは介さない）。[Layer5ScreenState.debugCompleteCurrentQuestion]は実際の
/// 録音停止と同じくarmedをfalseに戻す（サイコロ表示）ため、サイコロの
/// 軽いタップが「次の問題へ」の代わりになる。
Future<void> _completeAllQuestions(
  WidgetTester tester,
  Layer5ScreenState state,
) async {
  for (var i = 0; i < 10; i++) {
    state.debugCompleteCurrentQuestion('回答$i');
    await tester.pump();
    if (i < 9) {
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
    }
  }
}

/// 全10問回答→送信アイコン→確認ダイアログで「送信」までを行い、
/// 貼り付け待ち状態にする。
Future<void> _sendToChromeAi(
  WidgetTester tester,
  Layer5ScreenState state,
) async {
  await _completeAllQuestions(tester, state);
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump(_tapConfirmWait);
  await tester.pump();
  await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences.showStartupScreen = false;
    await PrivacyConsentService.grantSpeechProcessingConsent();
  });

  group('レイヤーⅤ：セッション開始・出題', () {
    testWidgets('セッション開始時に10問セッションが作られ、進捗と課題内容が表示される', (
      WidgetTester tester,
    ) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

      await _pumpLayer5(tester);

      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      expect(state.debugSession.questionCount, 10);
      expect(state.debugSession.currentIndex, 0);

      // 初期状態はサイコロ表示で問題文はまだ出ない。
      expect(find.byIcon(Icons.casino), findsOneWidget);
      expect(find.text('1 / 10'), findsNothing);

      // サイコロをタップすると問題が表示される。
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();

      expect(find.text('1 / 10'), findsOneWidget);
      final card = tester.widget<PronunciationExerciseCard>(
        find.byType(PronunciationExerciseCard),
      );
      expect(find.text(card.exercise.sentence), findsAtLeastNWidgets(1));
      expect(find.text(card.exercise.reading), findsAtLeastNWidgets(1));
      expect(find.text(card.exercise.vietnameseHint), findsAtLeastNWidgets(1));
    });

    testWidgets('各カテゴリ2問ずつ抽選される', (WidgetTester tester) async {
      await _pumpLayer5(tester);

      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      for (final category in PronunciationCategory.values) {
        final count = state.debugSession.questions
            .where((q) => q.exercise.category == category)
            .length;
        expect(count, 2, reason: '${category.storageKey}が2問であること');
      }
    });
  });

  group('レイヤーⅤ：録音・再録音', () {
    testWidgets('サイコロをタップしてマイクに変えてからタップしても、権限エラー等でも安全に失敗し、録音中状態には進まない', (
      WidgetTester tester,
    ) async {
      await _pumpLayer5(tester);

      // サイコロをタップして問題を表示し、マイクに切り替える。
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // startRecording()はpath_provider経由の実プラットフォームチャンネル呼び出しを
      // 含むため、FakeAsyncのpump()だけでは解決しない。runAsync()で実イベント
      // ループ上で完了させる。
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 開始に失敗しても、もう一度タップし直せるようマイク表示のままになる
      // （サイコロには戻らない）。
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      expect(
        state.debugSession.current.status,
        PronunciationQuestionStatus.waiting,
      );
    });

    testWidgets('STT結果が空でも安全に扱われ、サイコロのタップで次へ進める', (WidgetTester tester) async {
      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));

      state.debugMarkCurrentFailed();
      await tester.pump();
      expect(
        state.debugSession.current.status,
        PronunciationQuestionStatus.failed,
      );
      expect(find.byIcon(Icons.casino), findsOneWidget);

      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(state.debugSession.currentIndex, 1);
    });
  });

  group('レイヤーⅤ：全問完了・Chrome送信・貼り付け', () {
    testWidgets('全10問回答すると送信アイコン（GenkiTransportRow）が有効になる', (
      WidgetTester tester,
    ) async {
      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));

      await _completeAllQuestions(tester, state);

      final sendIgnorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byIcon(Icons.send_rounded),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(sendIgnorePointer.ignoring, isFalse);
    });

    testWidgets('送信アイコンをタップするとChrome AIが起動し、貼り付け待ちになる', (
      WidgetTester tester,
    ) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      final fakeUrlLauncher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));

      await _sendToChromeAi(tester, state);

      expect(fakeUrlLauncher.launchedUrls, hasLength(1));
      expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);
    });

    testWidgets('Google送信をキャンセルするとURLを開かず、貼り付け待ちにもならない', (
      WidgetTester tester,
    ) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      final fakeUrlLauncher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      await _completeAllQuestions(tester, state);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();

      expect(find.text(_t('Google送信確認_本文')), findsOneWidget);
      expect(find.text(_t('同意してGoogleへ送信')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, _t('キャンセル')));
      await tester.pump();

      expect(fakeUrlLauncher.launchedUrls, isEmpty);
      expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
    });

    testWidgets('回答を貼り付けると解析結果が即保存され、5カテゴリの星が履歴に残る', (
      WidgetTester tester,
    ) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      await _sendToChromeAi(tester, state);

      await Clipboard.setData(const ClipboardData(text: _validEvaluationJson));
      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // 貼り付け後は、その場で評価概要ダイアログを表示する。
      expect(find.text(_t('評価結果プレビュー')), findsOneWidget);
      // ダイアログ表示と同時に保存も完了していること。
      final saved = await PronunciationCheckStorage().loadAll();
      expect(saved, hasLength(1));
      // longVowel=5点なので★5、rRow=3点なので★3☆2（履歴一覧で確認）。
      expect(saved.single.evaluation, isNotNull);
      expect(
        saved.single.evaluation!.categoryEvaluations.values
            .map((e) => e.starDisplay)
            .toSet(),
        containsAll(['★★★★★', '★★★☆☆', '★☆☆☆☆', '★★☆☆☆', '★★★★☆']),
      );
    });

    testWidgets('言語設定が英語のときに送信すると、貼り付けたv2形式（feedback単一言語）の回答は'
        '英語のフィードバックだけが表示され、日本語・ベトナム語の併記にはならない', (WidgetTester tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      final originalLanguage = appSettings.language;
      appSettings.language = 'en';
      addTearDown(() => appSettings.language = originalLanguage);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      // 実際のアプリ表示言語（英語）で確認ダイアログのボタンが描画される
      // ため、共通ヘルパー（ベトナム語固定の_tを使う）ではなく、ここでは
      // 英語の翻訳文で「送信」ボタンを探す。
      await _completeAllQuestions(tester, state);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(
          TextButton,
          '同意してGoogleへ送信'.tr(appSettings.language),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await Clipboard.setData(
        const ClipboardData(text: _validEnglishEvaluationJson),
      );
      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      final saved = await PronunciationCheckStorage().loadAll();
      expect(saved, hasLength(1));
      final evaluation = saved.single.evaluation!;
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.feedback,
        'The tsu sound is a bit weak.',
      );
      // v1形式のように日本語・ベトナム語のフィードバックが併記されることはない。
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.feedbackJa,
        isNull,
      );
      expect(
        evaluation.categoryEvaluations[PronunciationCategory.tsu]!.feedbackVi,
        isNull,
      );
      expect(
        evaluation.displaySummary('en'),
        'Overall, you are practicing well.',
      );
    });

    testWidgets('Chromeから戻ったときクリップボードが送信プロンプトのままなら'
        '保存せず貼り付けボタンを残す', (WidgetTester tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      await _sendToChromeAi(tester, state);

      expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

      // Chrome へ行く直前にコピーしたプロンプトがまだクリップボードにある状態で
      // アプリへ復帰したとき、誤保存して貼り付け待ちを解除しない。
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);
      final saved = await PronunciationCheckStorage().loadAll();
      expect(saved, isEmpty);
    });
  });

  group('レイヤーⅤ：解析失敗時の保存', () {
    testWidgets('回答をAIが解析できない形式で返しても、AI回答原文つきで保存され'
        '（結果ダイアログは出さない）、履歴一覧・詳細画面に「未解析」と原文が表示される', (WidgetTester tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      // 詳細画面のListView(children:)が遅延レイアウトで下部までマウントされる
      // よう、ビューポートを十分に大きくしておく（他の詳細画面テストと同じ理由）。
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      await _sendToChromeAi(tester, state);

      const garbledText = 'JSONではない、ただの説明文だけの回答です。';
      await Clipboard.setData(const ClipboardData(text: garbledText));
      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // 解析失敗時は結果ダイアログを出さず、メッセージだけ表示する。
      expect(find.text(_t('評価結果プレビュー')), findsNothing);
      expect(find.text(_t('Chrome AIの回答を解析できませんでした')), findsOneWidget);
      // 保存済み扱いになり、貼り付け待ちは解除される（緑ボタンは消える）。
      expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);

      final saved = await PronunciationCheckStorage().loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.isLegacyFormat, isFalse);
      expect(saved.single.evaluation, isNull);
      expect(saved.single.unparsedResponse, garbledText);

      // pumpWidgetで新しいMaterialAppに差し替えても、同じruntimeTypeのため
      // 直前のScaffoldMessenger（保留中のSnackBar＝内部にDismissibleを持つ）が
      // 引き継がれてしまう。UniqueKeyでツリーを完全に作り直し、持ち越さない。
      await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: const PronunciationHistoryScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_t('未解析')), findsOneWidget);
      expect(find.text(garbledText), findsOneWidget);

      await tester.tap(find.byType(Dismissible));
      await tester.pumpAndSettle();

      expect(find.byType(PronunciationCheckDetailScreen), findsOneWidget);
      expect(find.text(_t('未解析')), findsOneWidget);
      // AI回答原文カードはSelectableText（find.textではなくtextContainingで拾う。
      // レイヤーⅤの既存テストと同じ理由）。
      expect(find.textContaining(garbledText), findsOneWidget);
    });
  });

  group('レイヤーⅤ：履歴保存・詳細表示', () {
    testWidgets('保存すると履歴一覧に日時・改善の重点・5カテゴリの星が表示され、'
        'タップした詳細画面に10問・STT結果・評価・フィードバック・AI回答原文が表示される', (
      WidgetTester tester,
    ) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      // 詳細画面は縦に長い（10問＋5カテゴリ評価＋AI回答原文）ため、
      // ListView(children:)の遅延レイアウトで下部がマウントされないまま
      // にならないよう、テスト用ビューポートを十分に大きくしておく。
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLayer5(tester);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      final askedSentences = state.debugSession.questions
          .map((q) => q.exercise.sentence)
          .toList();

      await _sendToChromeAi(tester, state);
      await Clipboard.setData(const ClipboardData(text: _validEvaluationJson));
      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // 貼り付け後は結果概要ダイアログが出るため、履歴画面検証へ進む前に閉じる。
      if (find.text(_t('評価結果プレビュー')).evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(TextButton, _t('完了')));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      final saved = await PronunciationCheckStorage().loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.isLegacyFormat, isFalse);
      expect(saved.single.evaluation, isNotNull);

      // 履歴一覧に日時・改善の重点・5カテゴリの星が表示される。
      await tester.pumpWidget(
        const MaterialApp(home: PronunciationHistoryScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_tFmt('改善の重点：%@', ['「つ」'])), findsOneWidget);
      expect(find.text('つ★☆☆☆☆'), findsOneWidget);
      expect(find.text('ざ★★★★☆'), findsOneWidget);
      expect(find.text('ラ★★★☆☆'), findsOneWidget);
      expect(find.text('長★★★★★'), findsOneWidget);
      expect(find.text('促★★☆☆☆'), findsOneWidget);

      // 詳細表示：一覧項目をタップすると詳細画面が開く。
      await tester.tap(find.byType(Dismissible));
      await tester.pumpAndSettle();

      expect(find.byType(PronunciationCheckDetailScreen), findsOneWidget);
      expect(find.text(_t('出題した10問')), findsOneWidget);
      for (final sentence in askedSentences) {
        expect(find.text(sentence), findsAtLeastNWidgets(1));
      }
      for (var i = 0; i < 10; i++) {
        expect(find.text('回答$i'), findsOneWidget);
      }
      expect(find.text(_t('AI回答原文')), findsOneWidget);
      expect(find.textContaining('全体的に良く練習できています。'), findsWidgets);
      // 日本語・ベトナム語のフィードバックが両方表示される。
      expect(find.text('「つ」の発音が弱いです。'), findsOneWidget);
      expect(find.text('Âm "つ" hơi yếu.'), findsOneWidget);
    });
  });

  group('レイヤーⅤ：旧形式データの閲覧', () {
    testWidgets('旧形式データは「旧形式」として履歴一覧・詳細画面で閲覧できる', (WidgetTester tester) async {
      final legacy = SavedPronunciationCheck(
        id: 'legacy_flow_test_1',
        createdAt: DateTime(2025, 1, 1, 9, 30),
        transcript: '「つ」の発音がやや弱いです（旧形式の自由記述フィードバック）。',
      );
      await PronunciationCheckStorage().save(legacy);

      await tester.pumpWidget(
        const MaterialApp(home: PronunciationHistoryScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_t('旧形式')), findsOneWidget);
      expect(find.text('「つ」の発音がやや弱いです（旧形式の自由記述フィードバック）。'), findsOneWidget);

      await tester.tap(find.byType(Dismissible));
      await tester.pumpAndSettle();

      expect(find.byType(PronunciationCheckDetailScreen), findsOneWidget);
      expect(find.text(_t('旧形式')), findsOneWidget);
      expect(
        find.text('旧形式のデータです（かつての自由発話・自由記述の記録です）。'.tr(_lang)),
        findsOneWidget,
      );
      expect(find.text('「つ」の発音がやや弱いです（旧形式の自由記述フィードバック）。'), findsOneWidget);
    });
  });
}
