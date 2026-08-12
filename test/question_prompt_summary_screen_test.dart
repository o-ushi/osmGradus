import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/theme/app_colors.dart';
import 'package:osm_gradus/views/layers/question_prompt_summary_screen.dart';
import 'package:osm_gradus/widgets/genki_transport_row.dart';
import 'package:osm_gradus/widgets/layer_numeral_badge.dart';
import 'package:osm_gradus/widgets/question_prompt_summary_score_header.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

Future<QuestionPrompt> _importPrompt(QuestionPrompt prompt) async {
  await QuestionPromptService().importPrompts([prompt]);
  return prompt;
}

Future<void> _pushSummary(WidgetTester tester, String promptId) async {
  await tester.pumpWidget(
    MaterialApp(home: QuestionPromptSummaryScreen(promptId: promptId)),
  );
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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('見つからないIDを開くと「問題文が見つかりません」を表示する', (tester) async {
    await _pushSummary(tester, 'no_such_id');

    expect(find.text(_t('問題文が見つかりません')), findsOneWidget);
  });

  testWidgets('未記入の問題文は各項目が「ー」になり、材料が無いので紙飛行機は出ない', (tester) async {
    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '未記入テスト問題文',
        source: QuestionPromptSource.manual,
      ),
    );

    await _pushSummary(tester, prompt.id);

    expect(find.text(prompt.body), findsOneWidget);
    expect(find.text(_t('レイヤーⅠタイトル')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤタイトル')), findsOneWidget);
    expect(find.byType(QuestionPromptSummaryScoreHeader), findsOneWidget);
    expect(find.byType(LayerNumeralIcon), findsNWidgets(10));
    // ヘッダーⅠ〜Ⅴの5点＋本文14項目（分からなかった単語・正解率・要約・
    // 結論・理由・例示・JSST・的中度・PREP・発音5カテゴリ）が未記入で「ー」。
    expect(find.text('ー'), findsNWidgets(19));
    expect(find.byType(GenkiTransportRow), findsNothing);
    expect(find.text(_t('総評_アドバイス_挑戦')), findsOneWidget);
  });

  testWidgets('記入済みの問題文は各レイヤーの値がそのまま表示され、紙飛行機が出る', (tester) async {
    final entries = await VocabularyService().addEntry('促進', 'thúc đẩy');
    final wordId = entries.first.id;

    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '記入済みテスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(
        registeredWordIds: [wordId],
        summary: 'これが回答の要約です',
        conclusion: '結論テキスト',
        reason: '理由テキスト',
        example: '具体例テキスト',
        jsstScore: 3,
        hitScore: 4,
        prepScore: 5,
        pronunciationScores: const {PronunciationCategory.tsu: 2},
      ),
    );

    await _pushSummary(tester, prompt.id);

    expect(find.text('促進'), findsOneWidget);
    expect(find.text('これが回答の要約です'), findsOneWidget);
    expect(find.text('結論テキスト'), findsOneWidget);
    expect(find.text('理由テキスト'), findsOneWidget);
    expect(find.text('具体例テキスト'), findsOneWidget);
    expect(find.text('JSST 5〜6'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // ヘッダー: Ⅰ未実施ー / Ⅱ的中度4 / Ⅲ PREP5 / Ⅳ 5~6 / Ⅴカテゴリ不足ー
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(0)),
          )
          .data,
      'ー',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(1)),
          )
          .data,
      '4',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(2)),
          )
          .data,
      '5',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(3)),
          )
          .data,
      '5~6',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(4)),
          )
          .data,
      'ー',
    );
    // 本文: 語彙テスト未実施の正解率1件＋発音は「つ」だけ記入済みで残り4カテゴリが
    // 未記入のまま「ー」。ヘッダーⅠ・Ⅴも「ー」（合計7件）。
    expect(find.text('ー'), findsNWidgets(7));

    expect(find.byType(GenkiTransportRow), findsOneWidget);
  });

  testWidgets('AI総評が既に保存されている問題文はアドバイス欄にそのまま表示される', (tester) async {
    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: 'アドバイス済みテスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(advice: '既に保存済みのアドバイス文'),
    );

    await _pushSummary(tester, prompt.id);

    expect(find.text('既に保存済みのアドバイス文'), findsOneWidget);
  });

  testWidgets('紙飛行機をタップすると、Google送信の同意ダイアログが開く（二重ガード回帰）', (tester) async {
    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '送信テスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(summary: '要約あり'),
    );

    await _pushSummary(tester, prompt.id);

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

  testWidgets('貼り付けで保存したアドバイスは、画面を閉じて開き直しても残る', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '保持確認テスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(summary: '要約あり'),
    );

    await _pushSummary(tester, prompt.id);

    final sendIcon = find.descendant(
      of: find.byType(GenkiTransportRow),
      matching: find.byIcon(Icons.send_rounded),
    );
    await tester.tap(sendIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(const ClipboardData(text: '保存されるべきアドバイス'));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('保存されるべきアドバイス'), findsOneWidget);

    // 画面を閉じて、新しいインスタンスとして開き直す（一覧から再度開く操作の再現）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _pushSummary(tester, prompt.id);

    expect(find.text('保存されるべきアドバイス'), findsOneWidget);
  });

  testWidgets('送信〜貼り付けの間に他画面で単語登録が反映されても、'
      'アドバイス保存時にその変更を消さない（Layer1等がIndexedStackで生き'
      '続けたまま更新するケースの回帰）', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    final entries = await VocabularyService().addEntry('促進', 'thúc đẩy');
    final wordId = entries.first.id;
    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '競合更新テスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(summary: '要約あり'),
    );

    await _pushSummary(tester, prompt.id);

    final sendIcon = find.descendant(
      of: find.byType(GenkiTransportRow),
      matching: find.byIcon(Icons.send_rounded),
    );
    await tester.tap(sendIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Chromeに切り替えている間に、別画面（例：レイヤーⅠの問題文詳細。
    // MainShellのIndexedStackで生きたまま）が同じ問題文へ単語登録を保存した
    // ことを再現する。総評画面はこの変更をまだ知らない（_promptは開いた
    // 時点のまま）。
    final concurrent = await QuestionPromptService().loadById(prompt.id);
    await QuestionPromptService().update(
      concurrent!.copyWith(registeredWordIds: [wordId]),
    );

    await Clipboard.setData(const ClipboardData(text: '並行更新後のアドバイス'));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final reloaded = await QuestionPromptService().loadById(prompt.id);
    expect(reloaded?.advice, '並行更新後のアドバイス');
    expect(reloaded?.registeredWordIds, [wordId]);
  });

  testWidgets('レイヤーⅠの正解率は淡々としたテキストのみで、総評から語彙テストを開始できない（Step 4）', (
    tester,
  ) async {
    final unfinished = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '語彙テスト未実施の問題文',
        source: QuestionPromptSource.manual,
      ),
    );

    await _pushSummary(tester, unfinished.id);

    expect(find.text(_t('正解率')), findsOneWidget);
    // 総評からは語彙テストを起動できない（旧「語彙力確認」ボタン相当は
    // どこにも存在しない）。
    expect(find.byIcon(Icons.quiz_rounded), findsNothing);
    expect(find.byType(TextButton), findsNothing);

    // 同じ位置に同じ型のウィジェットを積んだだけではStateが再利用され
    // initStateが再実行されないため、一度空にしてから開き直す。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    final done = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '語彙テスト実施済みの問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(vocabTestQuestionCount: 4, vocabTestCorrectCount: 3),
    );

    await _pushSummary(tester, done.id);

    final resultFinder = find.text('75%');
    expect(resultFinder, findsOneWidget);
    expect(find.byIcon(Icons.quiz_rounded), findsNothing);
    expect(find.byType(TextButton), findsNothing);

    // 他レイヤーのスコア欄（_FieldRowの値）と同じ、タップ不可の見た目。
    final resultText = tester.widget<Text>(resultFinder);
    expect(resultText.style?.fontSize, 15);
    expect(resultText.style?.color, AppColors.current.textOnCardPrimary);

    // ヘッダーⅠは正解率75% → 5点法で4。本文の75%とは役割を分ける。
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(0)),
          )
          .data,
      '4',
    );
  });

  testWidgets('総評ヘッダーは起動画面と同じⅠ〜Ⅴアイコンと換算点を並べる（Step 9）', (tester) async {
    final prompt = await _importPrompt(
      QuestionPrompt.create(
        category: TopicCategory.daily,
        body: 'ヘッダー表示テスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(
        vocabTestQuestionCount: 5,
        vocabTestCorrectCount: 5,
        hitScore: 5,
        prepScore: 4,
        jsstScore: 3,
        pronunciationScores: const {
          PronunciationCategory.tsu: 5,
          PronunciationCategory.zRow: 4,
          PronunciationCategory.rRow: 4,
          PronunciationCategory.longVowel: 3,
          PronunciationCategory.sokuon: 4,
        },
      ),
    );

    await _pushSummary(tester, prompt.id);

    final header = find.byType(QuestionPromptSummaryScoreHeader);
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.byType(LayerNumeralIcon)),
      findsNWidgets(5),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(0)),
          )
          .data,
      '5',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(1)),
          )
          .data,
      '5',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(2)),
          )
          .data,
      '4',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(3)),
          )
          .data,
      '5~6',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(3)),
          )
          .data,
      isNot(contains('〜')),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(3)),
          )
          .data,
      isNot(contains('-')),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(QuestionPromptSummaryScoreHeader.scoreKey(4)),
          )
          .data,
      '3',
    );
    // 本文のJSSTは従来どおり全角バンド。ヘッダーだけ半角 `~`。
    expect(find.text('JSST 5〜6'), findsOneWidget);
  });
}
