import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
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

  testWidgets('レイヤーⅡの入口は「問題文一覧から選ぶ」「ランダム」「話題を増やす」の3択', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
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
