import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'question_prompt_list_test_helpers.dart';
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
import 'package:osm_gradus/widgets/prep_stage_row.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「結論」「理由」「例示」「IV」等、ダブルタップの機能ヒントが付いた
/// ボタン（Step 7）はGestureDetector.onDoubleTapで単タップ判定を約300ms
/// （kDoubleTapTimeout）保留するため、単タップとして確定させるにはこの分
/// だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

Future<void> _openLayer3QuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅲ'));
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

  testWidgets('レイヤーⅢの入口は「問題文一覧から選ぶ」「ランダム」の2択', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅲ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
  });

  testWidgets('「ランダム」で既存のサイコロ・タイマー・PREPガイド画面が開く', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅲ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_t('ランダム')));
    // レイヤーⅢのPREPガイドは常時点滅する（無限に繰り返す）AnimationControllerを
    // 持つため、pumpAndSettle()は使わない。
    await tester.pump();

    expect(find.byType(PrepStageRow), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);
  });

  testWidgets('「問題文一覧から選ぶ」で問題文一覧（進捗＝PREP・PREPスコア列）が開く', (tester) async {
    await _openLayer3QuestionPromptList(tester);

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('PREP')), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byType(QuestionPromptListRow), findsWidgets);
    // レイヤーⅣ未実施のため、PREPスコア列は「ー」になる。
    expect(find.text('ー'), findsWidgets);
  });

  testWidgets('行タップで詳細が開き、予約席レイアウト（結論・理由・具体例・IV）を持つ', (tester) async {
    await _openLayer3QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);

    expect(find.byType(DiceActionRow), findsOneWidget);
    expect(find.byType(PrepLabelRow), findsOneWidget);
    // 3項目とも未記入なので白（橙ではない）。
    for (final icon in [
      Icons.flag_rounded,
      Icons.question_mark_rounded,
      Icons.lightbulb_rounded,
    ]) {
      expect(find.byIcon(icon), findsOneWidget);
      final widget = tester.widget<Icon>(find.byIcon(icon));
      expect(widget.color, isNot(Colors.orange));
    }
    // レイヤーⅢの本文は単語登録できない（レイヤーⅠ専用機能）。
    expect(find.byType(TappableJapaneseText), findsNothing);
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('結論・理由・具体例をすべて記入すると橙色になり、一覧の進捗に反映される', (tester) async {
    await _openLayer3QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);

    Future<void> fillField(IconData icon, String text) async {
      await tester.tap(find.byIcon(icon));
      await tester.pump(_tapConfirmWait);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text(_t('保存')));
      await tester.pumpAndSettle();
    }

    await fillField(Icons.flag_rounded, '結論テキスト');
    await fillField(Icons.question_mark_rounded, '理由テキスト');
    await fillField(Icons.lightbulb_rounded, '具体例テキスト');

    for (final icon in [
      Icons.flag_rounded,
      Icons.question_mark_rounded,
      Icons.lightbulb_rounded,
    ]) {
      final widget = tester.widget<Icon>(find.byIcon(icon));
      expect(widget.color, Colors.orange);
    }

    final all = await QuestionPromptService().loadAll();
    final updated = all.where((p) => p.isPrepFilled);
    expect(updated, hasLength(1));
    expect(updated.single.conclusion, '結論テキスト');
    expect(updated.single.reason, '理由テキスト');
    expect(updated.single.example, '具体例テキスト');
  });

  testWidgets('「IV」をタップするとレイヤーⅣの同じ問題文の詳細へスキップ遷移する', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final firstBody = all.first.body;

    await _openLayer3QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);

    await tester.tap(find.byType(LayerNumeralBadge));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // トップ・一覧をスキップし、Ⅲで開いていたのと同じ問題文のⅣ詳細が直接
    // 開く（固定の問題文に対する「開始」ボタンが見える。抽選のサイコロは
    // 使わないモードのためcasinoアイコンは出ない）。
    expect(find.text(firstBody), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsNothing);
  });

  testWidgets('詳細画面の常設ヘッダー「Ⅱ」をタップすると、レイヤーⅡの2択画面ではなく問題文一覧へ直接飛ぶ（回帰）', (
    tester,
  ) async {
    await _openLayer3QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);

    // レイヤーⅡは今回のセッションでまだ一度も訪れていない（_modeが未選択の
    // まま）状態で、詳細画面上端の常設ヘッダー「Ⅱ」をタップする。
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧')), findsOneWidget);
    expect(find.text(_t('問題文一覧から選ぶ')), findsNothing);
    expect(find.text(_t('話題を増やす')), findsNothing);
  });

  testWidgets('結論・理由・具体例・IVをダブルタップすると機能ヒントが出て、単タップの動作は実行されない', (tester) async {
    await _openLayer3QuestionPromptList(tester);
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);

    Future<void> doubleTap(Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
    }

    await doubleTap(find.byIcon(Icons.flag_rounded));
    expect(find.textContaining(_t('結論')), findsWidgets);
    // ダブルタップでは入力シートは開かない（本来の単タップ動作は実行しない）。
    expect(find.byType(TextField), findsNothing);

    await doubleTap(find.byIcon(Icons.question_mark_rounded));
    expect(find.textContaining(_t('理由')), findsWidgets);
    expect(find.byType(TextField), findsNothing);

    await doubleTap(find.byIcon(Icons.lightbulb_rounded));
    expect(find.textContaining(_t('例示')), findsWidgets);
    expect(find.byType(TextField), findsNothing);

    await doubleTap(find.byType(LayerNumeralBadge));
    expect(find.textContaining(_t('レイヤーⅣタイトル')), findsWidgets);
    // ダブルタップではレイヤーⅣへ遷移しない。
    expect(find.byType(LayerNumeralBadge), findsOneWidget);
  });

  testWidgets('詳細画面の▲▼ボタンで前後の問題文へ移動でき、移動できない方向は隠れる', (tester) async {
    await _openLayer3QuestionPromptList(tester);
    final firstRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).at(0),
    );
    final secondRow = tester.widget<QuestionPromptListRow>(
      find.byType(QuestionPromptListRow).at(1),
    );
    await tapQuestionPromptListRow(tester, row: find.byType(QuestionPromptListRow).first);
    expect(find.text(firstRow.body), findsOneWidget);

    // 先頭なので「前」（▲）は無く、「次」（▼）だけ出る。
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text(secondRow.body), findsOneWidget);
    expect(find.text(firstRow.body), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();
    expect(find.text(firstRow.body), findsOneWidget);
    // 先頭に戻ったので「前」（▲）は再び消える。
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
  });
}
