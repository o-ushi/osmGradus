import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/theme/app_colors.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/layer_numeral_badge.dart';
import 'package:osm_gradus/widgets/prep_label_row.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「要約」「III」等、ダブルタップの機能ヒントが付いたボタン（Step 7）は
/// GestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

/// 解答例の妥当性チェック（短すぎ／依頼文／URL除外）を通る長さのプレーンテキスト。
const _sampleAnswerPasteText =
    '電話ではまず結論から簡潔に話すことが大切です。相手の時間を意識して用件をまとめましょう。';
const _sampleAnswerRetryText =
    'リトライ後に取得できた模範解答です。結論から伝えて、理由と具体例を続けます。';

/// [question_prompt_summary_screen_test.dart]と同型のクリップボードモック。
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

/// [_mockClipboard]と同じだが、'Clipboard.getData'の最初の[emptyReads]回だけ
/// 空を返し、それ以降は[eventualText]を返す（Chrome→アプリ復帰直後の
/// 一過性の空振りを再現する）。'Clipboard.setData'は無視する（送信プロンプトの
/// 上書きを考慮しない単純化版。読み取りリトライの検証専用）。
void _mockFlakyClipboard(
  WidgetTester tester, {
  required int emptyReads,
  required String eventualText,
}) {
  var callCount = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          callCount++;
          return {'text': callCount <= emptyReads ? '' : eventualText};
        case 'Clipboard.setData':
          return null;
        default:
          return null;
      }
    },
  );
}

/// 同意ダイアログの「同意してGoogleへ送信」を確定し、送信直後に出る
/// 「コピー案内」SnackBarを明示的に消してから返す。
/// [layers_test.dart]の「登録→取消→再登録」テストと同じ理由で、SnackBarは
/// pump(duration)だけでは自動消去タイマーが必ず解決するとは限らず、残った
/// ままだと後続のfindsNothing判定やタップのヒットテストを狂わせるため、
/// ScaffoldMessengerState.clearSnackBars()で確実に消す。
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

/// 使い方シートの1行の先頭連番バッジ（1️⃣など）を取り除いた断片
/// （[layers_test.dart]の`_withoutBadge`と同型。`_HelpLineView`が描画時に
/// バッジを別ウィジェットへ分離するため、素の文字列では照合できない）。
String _withoutBadge(String key) =>
    _t(key).replaceFirst(RegExp('^[0-9]️⃣[ 　]*'), '');

/// [question_prompt_summary_screen_test.dart]と同型のurl_launcherフェイク。
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

Future<void> _openLayer2QuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅱ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('問題文一覧から選ぶ')));
  await tester.pumpAndSettle();
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

  testWidgets('レイヤーⅡの入口は「問題文一覧から選ぶ」「ランダム」「25マスで考える」「話題を増やす」の4択', (
    tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
    expect(find.text(_t('25マスで考える')), findsOneWidget);
    expect(find.text(_t('話題を増やす')), findsOneWidget);
  });

  testWidgets('「問題文一覧から選ぶ」で問題文一覧（進捗＝要約・的中度列）が開く', (tester) async {
    await _openLayer2QuestionPromptList(tester);

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('要約')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byType(QuestionPromptListRow), findsWidgets);
    // レイヤーⅣ未実施のため、的中度列は「ー」になる。
    expect(find.text('ー'), findsWidgets);
  });

  testWidgets('行タップで詳細が開き、予約席レイアウト（要約・III）を持つ', (tester) async {
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(DiceActionRow), findsOneWidget);
    expect(find.byType(PrepLabelRow), findsOneWidget);
    // 「要約」はレイヤーⅠの「理解」と同じく、余白ゼロのアイコンのみ
    // （文字ラベルだと3等分の枠で小さくなるため）。未記入は白のまま。
    expect(find.byIcon(Icons.summarize_rounded), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.summarize_rounded));
    expect(icon.color, isNot(Colors.orange));
    // レイヤーⅡの本文は単語登録できない（レイヤーⅠ専用機能）。
    expect(find.byType(TappableJapaneseText), findsNothing);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('「要約」アイコンをタップして入力すると橙色になり、一覧の進捗に反映される', (tester) async {
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.summarize_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストの要約です');
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.summarize_rounded));
    expect(icon.color, Colors.orange);

    final all = await QuestionPromptService().loadAll();
    expect(all.where((p) => p.summary == 'テストの要約です'), hasLength(1));
  });

  testWidgets('一覧詳細：＋長押しの使い方シートに①要約②解答例③IIIの順で並ぶ', (tester) async {
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅡ_問題文_使い方_要約'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅡ_問題文_使い方_解答例'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅡ_問題文_使い方_III'), findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('「解答例」アイコンが見え、タップで同意ダイアログが出てキャンセルできる', (tester) async {
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

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

  testWidgets('解答例：同意→Chrome起動→貼り付けで保存され、橙アイコンになり再表示でも残る', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    await _confirmChromeAiSend(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);

    // 送信後は貼り付け待ちだと分かるよう、アイコン・色が変わる
    // （Chromeでコピーする前に早すぎるタップをしにくくする実機報告対応）。
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.content_paste_go_rounded)).color,
      kPasteReadyColor,
    );

    // Chromeで回答をコピーしてアプリへ戻り、貼り付けアイコンを再タップして貼り付け。
    await Clipboard.setData(const ClipboardData(text: _sampleAnswerPasteText));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
    expect(icon.color, Colors.orange);

    final all = await QuestionPromptService().loadAll();
    expect(all.where((p) => p.sampleAnswer == _sampleAnswerPasteText), hasLength(1));

    // 画面を閉じて開き直しても残る（一覧から再度開く操作の再現）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );
  });

  testWidgets('解答例：クリップボードが空でも貼り付けシートから手動保存できる', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    await _confirmChromeAiSend(tester);

    // クリップボードは空のまま貼り付けタップ → 手動シートが開く。
    // （hint付きボタンはダブルタップ待ちがあるので、先に単タップ確定させる）
    await Clipboard.setData(const ClipboardData(text: ''));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    // 自動クリップボード再試行（最大約2秒）のあと、シートが開く。
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text(_t('レイヤーⅡ_解答例_貼り付けタイトル')), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, _sampleAnswerPasteText);
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );
    final all = await QuestionPromptService().loadAll();
    expect(
      all.where((p) => p.sampleAnswer == _sampleAnswerPasteText),
      hasLength(1),
    );
  });

  testWidgets(
    '解答例：クリップボードの読み取りが一過性に空でも、リトライで自動的に回復する'
    '（実機報告「貼り付け待ちなのに読み取り失敗する」の追加対策）',
    (tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _openLayer2QuestionPromptList(tester);
      await tester.tap(find.byType(QuestionPromptListRow).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pumpAndSettle();
      await _confirmChromeAiSend(tester);

      expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

      // ここから「最初の1回だけ空、2回目以降は実際の回答」を返すモックに
      // 差し替える（Chrome→アプリ復帰直後にクリップボードがOS側でまだ
      // 同期し切っておらず、一過性に空で返ってくる事象の再現）。
      _mockFlakyClipboard(
        tester,
        emptyReads: 1,
        eventualText: _sampleAnswerRetryText,
      );

      await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
      await tester.pump();
      // pumpAndSettle()はフレーム予約が無いと即座に抜けてしまい、フレームを
      // 伴わない素のFuture.delayed（リトライ待ち）を待ちきらないことがある
      // ため、リトライ間隔分は明示的にpumpで進める。
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 1回目の空読み取りだけでは失敗扱いにせず、メッセージも出さない。
      expect(find.byType(SnackBar), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
      expect(icon.color, Colors.orange);

      final all = await QuestionPromptService().loadAll();
      expect(
        all.where((p) => p.sampleAnswer == _sampleAnswerRetryText),
        hasLength(1),
      );
    },
  );

  testWidgets(
    '解答例：Chrome復帰の瞬間にまだ回答をコピーしていなくても失敗メッセージを出さず、'
    '貼り付け待ちを静かに継続する（「たまに取り込みに失敗する」回帰）',
    (tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
      _mockClipboard(tester);

      await _openLayer2QuestionPromptList(tester);
      await tester.tap(find.byType(QuestionPromptListRow).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pump(_tapConfirmWait);
      await tester.pumpAndSettle();
      await _confirmChromeAiSend(tester);

      // Chromeに切り替えてすぐ（回答をまだコピーしていない状態、クリップ
      // ボードはまだ送信したプロンプトのまま）に、アプリ切り替えアニメー
      // ションや通知バナー操作などでうっかりアプリへ復帰したケースを再現する。
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ここで pumpAndSettle() すると、SnackBar は表示から自動で消えるまでの
      // 時間も含めて一気に進めてしまい、実際は出ていたメッセージが
      // 「もう消えたあと」になって見えなくなるだけで検証にならない。
      // メッセージの有無は、消える前のこの時点で確認する。
      expect(tester.takeException(), isNull);
      expect(
        find.text(_t('Chrome AIの解析結果を読み取れませんでした')),
        findsNothing,
      );
      expect(
        find.text(
          _t(
            'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。',
          ),
        ),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();

      // 今度は実際にChromeで回答をコピーしてから戻る。
      await Clipboard.setData(const ClipboardData(text: _sampleAnswerPasteText));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // 自動貼り付けのクリップボードリトライ（最大約2秒）を進める。
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
      expect(icon.color, Colors.orange);

      final all = await QuestionPromptService().loadAll();
      expect(
        all.where((p) => p.sampleAnswer == _sampleAnswerPasteText),
        hasLength(1),
      );
    },
  );

  testWidgets('解答例が取得済みの問題文は、タップで同意ダイアログではなく読み取り専用シートで表示される（編集不可）', (
    tester,
  ) async {
    final prompt = QuestionPrompt.create(
      category: TopicCategory.daily,
      body: '解答例表示テスト問題文',
      source: QuestionPromptSource.manual,
    ).copyWith(sampleAnswer: '既存の解答例テキスト');
    await QuestionPromptService().importPrompts([prompt]);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('問題文一覧から選ぶ')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(prompt.body),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(prompt.body));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded)).color,
      Colors.orange,
    );

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsNothing);
    expect(find.text('既存の解答例テキスト'), findsOneWidget);
    // 編集不可：TextFieldは無く、キャンセル／保存ではなく閉じるのみ。
    expect(find.byType(TextField), findsNothing);
    expect(find.text(_t('閉じる')), findsOneWidget);
    expect(find.text(_t('保存')), findsNothing);

    await tester.tap(find.text(_t('閉じる')));
    await tester.pumpAndSettle();

    final reloaded = await QuestionPromptService().loadById(prompt.id);
    expect(reloaded?.sampleAnswer, '既存の解答例テキスト');
  });

  testWidgets('解答例の表示シート：長文でもキーボードは出ず、オーバーフローしない', (
    tester,
  ) async {
    final longAnswer =
        'さるので、良い気分転換にもなります。例えば、週末には少し時間をかけて、'
        'スパイスからカレーを作ったり、季節の野菜を使ったパスタを作ったりして'
        'います。自分の好みの味に調節できますし、完成した料理を家族や友人に'
        '「美味しい」と言って食べてもらえると、非常に嬉しく感じます。';
    final prompt = QuestionPrompt.create(
      category: TopicCategory.daily,
      body: '長文解答例テスト問題文',
      source: QuestionPromptSource.manual,
    ).copyWith(sampleAnswer: longAnswer);
    await QuestionPromptService().importPrompts([prompt]);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('問題文一覧から選ぶ')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(prompt.body),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(prompt.body));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 読み取り専用のため編集フィールド（＝キーボードの発生源）が無い。
    expect(find.byType(TextField), findsNothing);
    expect(find.text(longAnswer), findsOneWidget);

    await tester.tap(find.text(_t('閉じる')));
    await tester.pumpAndSettle();
  });

  testWidgets('「ランダム」は未抽選時に解答例アイコンが出ず、抽選後にタップで同意ダイアログが出てキャンセルできる', (
    tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

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

  testWidgets('ランダム：解答例の貼り付け待ち中にリセット・再抽選すると、貼り付け待ち状態も解除される'
      '（Step 7レビューで発見・修正した回帰）', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    await _confirmChromeAiSend(tester);

    // 貼り付け待ち中にリセット。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 別の問題文を引き直して解答例アイコンをタップしたとき、貼り付け待ちが
    // 残っていれば誤って貼り付け扱いになるところ、同意ダイアログが出る
    // （＝送信として正しく扱われている）ことを確認する。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('レイヤーⅡ_解答例_Google送信確認_タイトル')), findsOneWidget);
  });

  testWidgets('「III」をタップするとレイヤーⅢの同じ問題文の詳細へスキップ遷移する', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final firstBody = all.first.body;

    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // トップ・一覧をスキップし、Ⅱで開いていたのと同じ問題文のⅢ詳細が直接開く
    // （結論・理由・具体例のPREP記入アイコンとIVボタンが見える）。
    expect(find.text(firstBody), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('要約・IIIをダブルタップすると機能ヒントが出て、単タップの動作は実行されない', (tester) async {
    await _openLayer2QuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    Future<void> doubleTap(Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
    }

    await doubleTap(find.byIcon(Icons.summarize_rounded));
    expect(find.textContaining(_t('回答の要約')), findsWidgets);
    expect(find.byType(TextField), findsNothing);

    await doubleTap(find.byType(LayerNumeralBadge));
    expect(find.textContaining(_t('レイヤーⅢタイトル')), findsWidgets);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('レイヤーIIに寄り道してから再度「III」を押しても、常に同じ問題文の詳細へ直接飛ぶ（回帰）', (tester) async {
    await _openLayer2QuestionPromptList(tester);

    // 1件目の行→詳細→「III」で、Ⅲ側の一覧・トップを経由せずⅢ詳細へ飛ぶ
    // （Layer3QuestionPromptScreenが初めて生成されるケース）。
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(firstRow.body), findsOneWidget);

    // Ⅲ詳細をスワイプで閉じるとⅢの一覧（selectFromListモード）に戻る。
    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(find.text(_t('問題文一覧')), findsOneWidget);

    // レイヤーⅡへ寄り道して、別の問題文の行を開く。
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    final secondRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).at(1),
    );
    await tester.tap(find.byType(QuestionPromptListRow).at(1));
    await tester.pumpAndSettle();

    // 再度「III」。Ⅲ側は既にselectFromListモードのまま（initStateは再実行
    // されない）だが、それでも一覧ではなく新しい問題文の詳細へ直接飛ぶこと。
    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(secondRow.body), findsOneWidget);
    expect(find.text(_t('問題文一覧')), findsNothing);
  });
}

/// [SwipeToCloseWrapper]の右スワイプ判定（左端スタート＋速度）を満たす、
/// layers_test.dartと同じ合成ジェスチャー。
Future<void> _rightSwipeFrom(WidgetTester tester, Offset start) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(
    const Offset(40, 0),
    timeStamp: const Duration(milliseconds: 10),
  );
  await gesture.moveBy(
    const Offset(80, 0),
    timeStamp: const Duration(milliseconds: 20),
  );
  await gesture.moveBy(
    const Offset(120, 0),
    timeStamp: const Duration(milliseconds: 30),
  );
  await gesture.moveBy(
    const Offset(60, 0),
    timeStamp: const Duration(milliseconds: 40),
  );
  await gesture.up(timeStamp: const Duration(milliseconds: 40));
}
