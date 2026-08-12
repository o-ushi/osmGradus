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
import 'package:osm_gradus/services/thinking_matrix_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

const _themeNames = ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'];

/// レイヤーⅢ入口→「25マスで考える」まで進める。
Future<void> _openLayer3ThinkingMatrix(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅲ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('25マスで考える')));
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

  testWidgets('レイヤーⅢ入口が3択（問題文一覧から選ぶ／ランダム／25マスで考える）になっている', (
    tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅲ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
    expect(find.text(_t('25マスで考える')), findsOneWidget);
    // 「話題を増やす」はレイヤーⅡだけの4択目。
    expect(find.text(_t('話題を増やす')), findsNothing);
  });

  testWidgets('Ⅱ相当（Service経由）で作ったセットのキーワードが、Ⅲの一覧・盤面でも見える', (
    tester,
  ) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    await service.upsertCellLayer2(
      setId: set.id,
      themeId: set.themes.first.id,
      columnId: set.columns.first.id,
      keyword: '海老名SAのメロンパン',
    );

    await _openLayer3ThinkingMatrix(tester);

    // セットが既にあるため、自動カテゴリ選択は出ず一覧が見える。
    expect(find.text(set.title), findsOneWidget);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    expect(find.text('海老名SAのメロンパン'), findsOneWidget);
  });

  testWidgets('Ⅲのセルシートには結論・理由・例示欄があり、保存するとサービスに残る', (
    tester,
  ) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text(_t('結論')), findsOneWidget);
    // 「理由」は汎用5列見出しの1つと同じ文言のため、シート内のラベルと合わせて
    // 2つ見える（列見出しはシートの背面にまだ存在するため）。
    expect(find.text(_t('理由')), findsWidgets);
    expect(find.text(_t('例示')), findsOneWidget);
    expect(find.text(_t('1分話した')), findsNothing);
    // 「母語で60秒スピーチ」ボタンはあるが、キーワードが空の間はdisabled。
    expect(find.text(_t('母語で60秒スピーチ')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, _t('母語で60秒スピーチ')),
          )
          .onPressed,
      isNull,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'キーワード');
    await tester.enterText(fields.at(1), '結論です');
    await tester.enterText(fields.at(2), '理由です');
    await tester.enterText(fields.at(3), '例示です');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    final updated = await service.loadById(set.id);
    final cell = updated!.cellFor(set.themes.first.id, set.columns.first.id);
    expect(cell.keyword, 'キーワード');
    expect(cell.conclusion, '結論です');
    expect(cell.reason, '理由です');
    expect(cell.example, '例示です');
  });

  testWidgets('1行のPREPが揃うとトロフィー2つ（60秒スピーチ前は3つにならない）', (tester) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    for (final column in set.columns) {
      await service.upsertCellLayer3(
        setId: set.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
        conclusion: '結論',
        reason: '理由',
        example: '例示',
      );
    }

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(2));
  });

  testWidgets(
    'Ⅲのセルシートで「母語で60秒スピーチ」をタップすると、確認を挟まず直接カウントダウンが始まり、保存でspeech60Doneが残る',
    (tester) async {
      final service = ThinkingMatrixService();
      final set = await service.createSet(
        title: 'テストセット',
        themeNames: _themeNames,
      );

      await _openLayer3ThinkingMatrix(tester);
      await tester.tap(find.text(set.title));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'キーワード');
      await tester.pump();

      final enabledButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, _t('母語で60秒スピーチ')),
      );
      expect(enabledButton.onPressed, isNotNull);

      // タップ直後（アラートを挟まず）にカウントダウンが残り60秒から始まる
      // （pumpAndSettle()はTimer.periodicが動いている間は終わらないため使わない）。
      await tester.tap(find.text(_t('母語で60秒スピーチ')));
      await tester.pump();
      expect(find.text('60${'秒'.tr(_lang)}'), findsOneWidget);

      // 60秒分フェイククロックを進めて完了させる。
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();

      await tester.tap(find.text(_t('マスを埋める')));
      await tester.pumpAndSettle();

      final updated = await service.loadById(set.id);
      final cell = updated!.cellFor(
        set.themes.first.id,
        set.columns.first.id,
      );
      expect(cell.speech60Done, isTrue);
    },
  );

  testWidgets('speech60Done後にチェックマークを長押しすると、スピーチしていない状態に戻る', (
    tester,
  ) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    final firstColumn = set.columns.first;
    await service.upsertCellLayer3(
      setId: set.id,
      themeId: firstTheme.id,
      columnId: firstColumn.id,
      keyword: 'キーワード',
      conclusion: '結論',
      reason: '理由',
      example: '例示',
      speech60Done: true,
    );

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    await tester.tap(find.text('キーワード').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.longPress(find.byIcon(Icons.check_circle_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    final updated = await service.loadById(set.id);
    final cell = updated!.cellFor(firstTheme.id, firstColumn.id);
    expect(cell.speech60Done, isFalse);
  });

  testWidgets('60秒スピーチのカウント中にキャンセルすると、保存されずspeech60Doneは変わらない', (
    tester,
  ) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    final firstColumn = set.columns.first;
    await service.upsertCellLayer3(
      setId: set.id,
      themeId: firstTheme.id,
      columnId: firstColumn.id,
      keyword: 'キーワード',
      conclusion: '結論',
      reason: '理由',
      example: '例示',
    );

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    await tester.tap(find.text('キーワード').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(_t('母語で60秒スピーチ')));
    await tester.pump();

    // カウント完了前にキャンセルで閉じる（保存しない）。
    await tester.tap(find.text(_t('キャンセル')));
    await tester.pumpAndSettle();

    final updated = await service.loadById(set.id);
    final cell = updated!.cellFor(firstTheme.id, firstColumn.id);
    expect(cell.speech60Done, isFalse);
  });

  testWidgets('1行がPREP＋speech60Doneまで揃うとトロフィー4つ', (tester) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    for (final column in set.columns) {
      await service.upsertCellLayer3(
        setId: set.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
        conclusion: '結論',
        reason: '理由',
        example: '例示',
        speech60Done: true,
      );
    }

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(4));
  });

  testWidgets('1行がPREP未完了でもspeech60Doneだけ揃えばトロフィー3つ', (tester) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    for (final column in set.columns) {
      await service.upsertCellLayer3(
        setId: set.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
        speech60Done: true,
        // PREP（結論・理由・例示）は空のまま。
      );
    }

    await _openLayer3ThinkingMatrix(tester);
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(3));
  });

  testWidgets('Ⅲで入れたPREPがあっても、Ⅱで同じセットを開くとトロフィーは1つのまま', (
    tester,
  ) async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'テストセット',
      themeNames: _themeNames,
    );
    final firstTheme = set.themes.first;
    for (final column in set.columns) {
      await service.upsertCellLayer3(
        setId: set.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
        conclusion: '結論',
        reason: '理由',
        example: '例示',
      );
    }

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('25マスで考える')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(set.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });
}
