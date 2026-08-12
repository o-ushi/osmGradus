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
import 'package:osm_gradus/models/question_prompt_vocab_word.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/views/layers/layer1_vocab_screen.dart';
import 'package:osm_gradus/views/topics/question_prompt_filter_sheet.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/layer_numeral_badge.dart';
import 'package:osm_gradus/widgets/prep_label_row.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';
import 'package:osm_gradus/widgets/transport_icon_button.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);
String _hintMessage(String tapText) =>
    '${'ボタンヒント_タップ'.trFmt(_lang, [tapText])}\n'
    '${'ボタンヒント_長押し'.trFmt(_lang, [_t('ボタンヒント_長押しなし')])}';

/// 「問題作成」「II」等、ダブルタップの機能ヒントが付いたボタン（Step 7）
/// はGestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

const _validVocabExtractionJson = '''
{"words":[{"word":"促進","reading":"そくしん","pos":"名詞","jlpt":"N2",
"meaning":"thúc đẩy","example":"経済成長を促進する。",
"exampleTranslation":"Thúc đẩy tăng trưởng kinh tế."}]}
''';

Future<void> _openQuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('問題文解析')));
  await tester.pumpAndSettle();
}

TransportIconButton _enrichButton(WidgetTester tester) =>
    tester.widget<TransportIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.translate_rounded),
        matching: find.byType(TransportIconButton),
      ),
    );

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

  testWidgets('3択に「問題文解析」が増え、タップすると一覧（進捗＋フィルタ）が開く', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    expect(find.text(_t('問題文解析')), findsOneWidget);
    expect(find.text(_t('長文読解')), findsOneWidget);
    expect(find.text(_t('語彙テスト')), findsOneWidget);

    await tester.tap(find.text(_t('問題文解析')));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('語彙テスト')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    // 組み込み30件（日常10・ビジネス10・シチュエーション10）は一覧の
    // データとしてすべて読み込まれるが、画面には収まる分だけ描画される。
    expect(find.byType(QuestionPromptListRow), findsWidgets);
    final all = await QuestionPromptService().loadAll();
    expect(all, hasLength(30));
  });

  testWidgets('行タップで詳細が開き、既存レイヤーと同じ予約席レイアウトを持つ', (tester) async {
    await _openQuestionPromptList(tester);

    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    // 上段: DiceActionRow（45/60/15+60はダミー、＋は表示）。
    expect(find.byType(DiceActionRow), findsOneWidget);
    // 本文はTappableJapaneseTextで単語登録できる。
    expect(find.byType(TappableJapaneseText), findsOneWidget);
    // 「問題作成」枠（アイコン、未実施は輪郭色）・下段の訳付/単語帳/IIボタン。
    expect(find.byType(PrepLabelRow), findsOneWidget);
    expect(find.byIcon(Icons.quiz_outlined), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
    expect(find.byIcon(Icons.style_rounded), findsOneWidget);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('「問題作成」タップでGoogle送信の同意ダイアログが開き、貼り付けで抽出単語が保存される', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    await _openQuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    final iconBefore = tester.widget<Icon>(find.byIcon(Icons.quiz_outlined));
    expect(iconBefore.color, isNot(Colors.orange));

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pump(_tapConfirmWait);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(
      const ClipboardData(text: _validVocabExtractionJson),
    );
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // 貼り付け完了後はアイコンが問題作成アイコンに戻り、色だけ橙になる
    // （抽出済みを示す。旧「理解」トグルと同じ配色）。
    final iconAfter = tester.widget<Icon>(find.byIcon(Icons.quiz_outlined));
    expect(iconAfter.color, Colors.orange);

    final all = await QuestionPromptService().loadAll();
    final updated = all.singleWhere((p) => p.vocabTestWords.isNotEmpty);
    expect(updated.vocabTestWords, hasLength(1));
    expect(updated.vocabTestWords.single.word, '促進');
    expect(updated.vocabTestWords.single.reading, 'そくしん');
    expect(updated.vocabTestWords.single.meaning, 'thúc đẩy');
    // vocabTestWordsの抽出だけではまだ語彙テスト未実施のため、
    // isLayer1Doneは立たない（Step 3で語彙テストを完結させて初めて立つ）。
    expect(updated.isLayer1Done, isFalse);
  });

  testWidgets('抽出済みなら「問題作成」タップで語彙テストが開始し、採点完了で正解率が保存され、'
      '不正解語が単語帳に自動登録される（既存重複は二重登録しない、Step 3）', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    // 「促進」は既に単語帳にある状態を用意しておく（二重登録されないことの確認用）。
    final dupEntries = await VocabularyService().addEntry(
      '促進',
      '旧訳',
      reading: '旧読み',
    );
    final dupId = dupEntries.first.id;

    final prompt =
        QuestionPrompt.create(
          category: TopicCategory.daily,
          body: 'Step3語彙テスト対象の問題文',
          source: QuestionPromptSource.manual,
        ).copyWith(
          vocabTestWords: const [
            QuestionPromptVocabWord(
              word: '調整',
              reading: 'ちょうせい',
              meaning: 'điều chỉnh',
              example: 'スケジュールを調整する。',
              exampleTranslation: 'Điều chỉnh lịch trình.',
            ),
            QuestionPromptVocabWord(
              word: '促進',
              reading: 'そくしん',
              meaning: 'thúc đẩy',
              example: '経済成長を促進する。',
              exampleTranslation: 'Thúc đẩy tăng trưởng kinh tế.',
            ),
          ],
        );
    await QuestionPromptService().importPrompts([prompt]);

    await _openQuestionPromptList(tester);
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('手入力')));
    await tester.tap(find.text(_t('完了')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Step3語彙テスト対象の問題文'));
    await tester.pumpAndSettle();

    // 抽出済みなので、タップで直接語彙テストが開く（Chrome AI往復はしない）。
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.byType(Layer1VocabScreen), findsOneWidget);

    final vocabState = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    final diceButton = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == Icons.casino &&
          (widget.size ?? 0) >= 40,
    );

    await tester.tap(diceButton);
    await tester.pump();
    expect(vocabState.debugSession!.questionCount, 2);
    final total = vocabState.debugSession!.questionCount;
    for (var i = 0; i < total; i++) {
      vocabState.debugCompleteWithSttAnswer('回答$i');
      await tester.pump();
      if (i < total - 1) {
        await tester.tap(diceButton);
        await tester.pump();
      }
    }

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1問目（調整）正解・2問目（促進）不正解。
    await Clipboard.setData(
      const ClipboardData(
        text:
            '{"questionEvaluations":['
            '{"correct":true,"feedback":"ok"},'
            '{"correct":false,"feedback":"ng"}'
            '],"overallScore":3,"summary":"まずまずです。"}',
      ),
    );
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(milliseconds: 300));

    // 結果ダイアログを閉じる。
    await tester.tap(find.widgetWithText(TextButton, _t('完了')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 語彙テスト画面を右スワイプで閉じ、レイヤーⅠ詳細へ戻る。
    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pumpAndSettle();

    final updated = (await QuestionPromptService().loadById(prompt.id))!;
    expect(updated.vocabTestCorrectCount, 1);
    expect(updated.vocabTestQuestionCount, 2);
    expect(updated.isLayer1Done, isTrue);

    final vocabEntries = await VocabularyService().loadEntries();
    // 「調整」は正解だったので単語帳には追加されない。
    expect(vocabEntries.where((e) => e.word == '調整'), isEmpty);
    // 「促進」は不正解だが、既存の同表記エントリを再利用し二重登録しない。
    expect(vocabEntries.where((e) => e.word == '促進'), hasLength(1));
    expect(updated.registeredWordIds, contains(dupId));

    // 「問題作成」アイコンは実施済み（橙）のまま詳細に戻っている。
    expect(find.byIcon(Icons.quiz_outlined), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.quiz_outlined));
    expect(icon.color, Colors.orange);
  });

  testWidgets('抽出済みの問題文で「問題作成」をダブルタップすると、実際の単タップ動作'
      '（語彙テスト開始）と一致したヒントが出る（実機で「問題作成」のまま'
      'ズレていた回帰）', (tester) async {
    final prompt =
        QuestionPrompt.create(
          category: TopicCategory.daily,
          body: 'ヒント確認用の問題文',
          source: QuestionPromptSource.manual,
        ).copyWith(
          vocabTestWords: const [
            QuestionPromptVocabWord(
              word: '調整',
              reading: 'ちょうせい',
              meaning: 'điều chỉnh',
              example: 'スケジュールを調整する。',
              exampleTranslation: 'Điều chỉnh lịch trình.',
            ),
          ],
        );
    await QuestionPromptService().importPrompts([prompt]);

    await _openQuestionPromptList(tester);
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('手入力')));
    await tester.tap(find.text(_t('完了')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ヒント確認用の問題文'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pump(const Duration(milliseconds: 100));

    // 単タップなら語彙テストが開くはず（「問題作成」＝Chrome AI抽出では
    // ない）。ヒントもそれに合わせて「語彙テスト」であるべきで、
    // 抽出前と同じ「問題作成」のままでは実際の動作と食い違う。
    expect(find.text(_hintMessage(_t('語彙テスト'))), findsOneWidget);
    expect(find.text(_hintMessage(_t('問題作成'))), findsNothing);
    // ダブルタップなので語彙テスト画面は開かない。
    expect(find.byType(Layer1VocabScreen), findsNothing);
  });

  testWidgets('本文の単語をタップすると単語帳へ登録され、「訳を付ける」が使えるようになる', (tester) async {
    await _openQuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    expect(_enrichButton(tester).visible, isFalse);

    final textTopLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.tapAt(textTopLeft + const Offset(6, 10));
    await tester.pump();

    expect(await VocabularyService().loadEntries(), isNotEmpty);
    expect(_enrichButton(tester).visible, isTrue);

    final all = await QuestionPromptService().loadAll();
    expect(all.where((p) => p.registeredWordIds.isNotEmpty), hasLength(1));
  });

  testWidgets('フィルタシートで入手元・カテゴリ・語彙テスト実施状況を絞り込める', (tester) async {
    await _openQuestionPromptList(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPromptFilterSheet), findsOneWidget);
    expect(find.text(_t('入手元')), findsOneWidget);
    expect(find.text(_t('カテゴリ')), findsOneWidget);
    expect(find.text(_t('語彙テスト実施状況')), findsOneWidget);

    // 「済み」を選ぶ→組み込みは全件語彙テスト未実施なので0件になる。
    await tester.tap(find.text(_t('済み')));
    await tester.tap(find.text(_t('完了')));
    await tester.pumpAndSettle();

    expect(find.byType(QuestionPromptListRow), findsNothing);
    expect(find.text(_t('問題文がありません')), findsOneWidget);
  });

  testWidgets('「II」をタップするとレイヤーⅡの同じ問題文の詳細へスキップ遷移する', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final firstBody = all.first.body;

    await _openQuestionPromptList(tester);
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // トップ・一覧をスキップし、Ⅰで開いていたのと同じ問題文のⅡ詳細が直接開く。
    expect(find.text(firstBody), findsOneWidget);
    expect(find.byIcon(Icons.summarize_rounded), findsOneWidget);
    expect(find.byType(TappableJapaneseText), findsNothing);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('レイヤーIに寄り道してから再度「II」を押しても、常に同じ問題文の詳細へ直接飛ぶ（回帰）', (tester) async {
    await _openQuestionPromptList(tester);

    // 1件目の行→詳細→「II」で、Ⅱ側の一覧・トップを経由せずⅡ詳細へ飛ぶ
    // （Layer2QuestionPromptScreenが初めて生成されるケース）。
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );
    await tester.tap(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(firstRow.body), findsOneWidget);

    // Ⅱ詳細をスワイプで閉じるとⅡの一覧（selectFromListモード）に戻る。
    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(find.text(_t('問題文一覧')), findsOneWidget);

    // レイヤーⅠへ寄り道して、別の問題文の行を開く。
    await tester.tap(find.text('Ⅰ'));
    await tester.pumpAndSettle();
    final secondRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).at(1),
    );
    await tester.tap(find.byType(QuestionPromptListRow).at(1));
    await tester.pumpAndSettle();

    // 再度「II」。Ⅱ側は既にselectFromListモードのまま（initStateは再実行され
    // ない）だが、それでも一覧ではなく新しい問題文の詳細へ直接飛ぶこと。
    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(secondRow.body), findsOneWidget);
    expect(find.text(_t('問題文一覧')), findsNothing);
  });

  testWidgets('一覧の「＋」をタップすると問題文追加の選択シートが開き、長押しすると使い方が開く', (tester) async {
    await _openQuestionPromptList(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(_t('自分で追加')), findsOneWidget);
    expect(find.text(_t('AIで追加')), findsOneWidget);
    // シート外（スクリム）をタップして閉じる。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(_t('操作方法')), findsOneWidget);
  });

  testWidgets('組み込みの問題文は左スワイプしても削除できない', (tester) async {
    await _openQuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).first,
    );

    await tester.drag(
      find.byType(QuestionPromptListRow).first,
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text(_t('標準問題文は削除できません')), findsOneWidget);
    expect(find.text(firstRow.body), findsOneWidget);
  });

  testWidgets('手入力で追加した問題文は左スワイプ→確認で削除できる', (tester) async {
    await QuestionPromptService().recordImport(
      category: TopicCategory.daily,
      bodies: ['スワイプ削除テスト用の問題文'],
      source: QuestionPromptSource.manual,
    );

    await _openQuestionPromptList(tester);
    // 組み込みが多数あり一覧が長いため、フィルタで「手入力」に絞って
    // 対象の行を確実に表示範囲へ入れる。
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('手入力')));
    await tester.tap(find.text(_t('完了')));
    await tester.pumpAndSettle();
    expect(find.text('スワイプ削除テスト用の問題文'), findsOneWidget);

    await tester.drag(find.text('スワイプ削除テスト用の問題文'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text(_t('削除しますか？')), findsOneWidget);
    await tester.tap(find.text(_t('削除')));
    await tester.pumpAndSettle();

    expect(find.text('スワイプ削除テスト用の問題文'), findsNothing);
    final all = await QuestionPromptService().loadAll();
    expect(all.where((p) => p.body == 'スワイプ削除テスト用の問題文'), isEmpty);
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
