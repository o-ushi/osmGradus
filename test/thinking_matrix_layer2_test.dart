import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/thinking_matrix_cell_status.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/thinking_matrix_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 入口タップまで進める。セット0件のため、この直後にカテゴリ選択シートが
/// 自動で開く（Step 3）。
Future<void> _openLayer2ThinkingMatrix(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅱ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('25マスで考える')));
  await tester.pumpAndSettle();
}

/// 開いているカテゴリ選択シートで「オリジナル」を選び、テーマ5欄入力画面へ進む。
Future<void> _pickOriginalCategory(WidgetTester tester) async {
  await tester.tap(find.text(_t('オリジナル')));
  await tester.pumpAndSettle();
}

const _themeNames = ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'];

/// 入口→カテゴリ選択（オリジナル）→登録→作成を経てボード
/// （5×5・全マスempty）まで進める。
Future<void> _createBoard(WidgetTester tester) async {
  await _openLayer2ThinkingMatrix(tester);
  await _pickOriginalCategory(tester);
  for (var i = 0; i < _themeNames.length; i++) {
    await tester.enterText(find.byType(TextField).at(i + 1), _themeNames[i]);
    await tester.pump();
  }
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

/// [skipThemeId]×[skipColumnId]の1マスを除く24マスをServiceで直接埋める
/// （UIのアイコン順に依存しないセットアップ）。
Future<void> _fillAllExceptOne(
  String setId, {
  required String skipThemeId,
  required String skipColumnId,
}) async {
  final service = ThinkingMatrixService();
  final set = await service.loadById(setId);
  for (final theme in set!.themes) {
    for (final column in set.columns) {
      if (theme.id == skipThemeId && column.id == skipColumnId) continue;
      await service.upsertCellLayer2(
        setId: setId,
        themeId: theme.id,
        columnId: column.id,
        keyword: 'キーワード',
      );
    }
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

  testWidgets('レイヤーⅡ入口に「25マスで考える」がある', (tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();

    expect(find.text(_t('25マスで考える')), findsOneWidget);
  });

  testWidgets('「25マスで考える」をタップするとカテゴリ選択（日常/ビジネス/シチュエーション/オリジナル）が見える', (
    tester,
  ) async {
    await _openLayer2ThinkingMatrix(tester);

    expect(find.text(_t('日常')), findsOneWidget);
    expect(find.text(_t('ビジネス')), findsOneWidget);
    expect(find.text(_t('シチュエーション')), findsOneWidget);
    expect(find.text(_t('オリジナル')), findsOneWidget);
    // 25マス作成に「ランダム」は出さない。
    expect(find.text(_t('ランダム')), findsNothing);
  });

  testWidgets('「オリジナル」を選ぶとテーマ登録画面（タイトル+テーマ5フィールド）が出る', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await _pickOriginalCategory(tester);

    expect(find.text(_t('テーマ')), findsOneWidget);
    // タイトル欄1つ + テーマ欄5つ = 6つのTextField。
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text(_t('25マスボードを作成')), findsOneWidget);
  });

  testWidgets('オリジナルで4つだけ入力では作成ボタンが押せず、セットもできない', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await _pickOriginalCategory(tester);

    final themeFields = find.byType(TextField).evaluate().skip(1).toList();
    expect(themeFields.length, 5);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i + 1), 'テーマ${i + 1}');
      await tester.pump();
    }

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    final sets = await ThinkingMatrixService().loadAll();
    expect(sets, isEmpty);
  });

  testWidgets('オリジナルで5つ入力して作成すると汎用5列の盤面に進み、テーマ名と25マスが見える', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await _pickOriginalCategory(tester);

    const themeNames = ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'];
    for (var i = 0; i < themeNames.length; i++) {
      await tester.enterText(find.byType(TextField).at(i + 1), themeNames[i]);
      await tester.pump();
    }

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    for (final name in themeNames) {
      expect(find.text(name), findsOneWidget);
    }
    // 時間・視点・比較・規模・理由の汎用5列見出しが見える。
    for (final columnLabel in ['時間', '視点', '比較', '規模', '理由']) {
      expect(find.text(_t(columnLabel)), findsOneWidget);
    }
    // 5×5のマスすべてがempty見た目（「＋」アイコン）で25個並ぶ。
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(25));

    final sets = await ThinkingMatrixService().loadAll();
    expect(sets, hasLength(1));
    expect(sets.first.category, isNull);
    expect(sets.first.themes.map((t) => t.name), themeNames);
    expect(sets.first.cells, hasLength(25));
  });

  testWidgets('「日常」を選ぶとテーマ入力をスキップしてすぐ盤面に進み、行に「趣味」等が見える', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await tester.tap(find.text(_t('日常')));
    await tester.pumpAndSettle();

    for (final themeName in ['趣味', '健康', '買い物', '旅行', '季節']) {
      expect(find.text(_t(themeName)), findsOneWidget);
    }
    for (final columnLabel in ['時間', '視点', '比較', '規模', '理由']) {
      expect(find.text(_t(columnLabel)), findsOneWidget);
    }
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(25));

    final sets = await ThinkingMatrixService().loadAll();
    expect(sets, hasLength(1));
    expect(sets.first.category, TopicCategory.daily);
    expect(sets.first.cells, hasLength(25));
  });

  testWidgets('「シチュエーション」を選ぶと列が3つ（職場・学校・病院）、セルが15になる', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await tester.tap(find.text(_t('シチュエーション')));
    await tester.pumpAndSettle();

    for (final themeName in ['相談', '依頼', '断り', '謝罪', '提案']) {
      expect(find.text(_t(themeName)), findsOneWidget);
    }
    for (final columnLabel in ['職場', '学校', '病院']) {
      expect(find.text(_t(columnLabel)), findsOneWidget);
    }
    // 時間・比較・規模の汎用5列見出しは出ない（視点は横軸の総称ラベルとして
    // カテゴリ問わず出るため対象外）。
    for (final columnLabel in ['時間', '比較', '規模']) {
      expect(find.text(_t(columnLabel)), findsNothing);
    }
    // 5テーマ×3列＝15マス。
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(15));

    final sets = await ThinkingMatrixService().loadAll();
    expect(sets, hasLength(1));
    expect(sets.first.category, TopicCategory.situational);
    expect(sets.first.columns.map((c) => c.id), [
      'workplace',
      'school',
      'hospital',
    ]);
    expect(sets.first.cells, hasLength(15));
  });

  testWidgets('一覧の「＋」を長押しすると使い方（追加・詳細・削除）が開く', (tester) async {
    await _createBoard(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text(_t('操作方法')), findsOneWidget);
    // LayerHelpLineは行頭の連番バッジ・{{icon}}を別Textとして切り出して描画
    // するため、バッジより後ろの本文部分だけを確認する。
    expect(find.textContaining('để chọn danh mục và tạo bộ mới'), findsOneWidget);
    // Step 8: 標準3シートが最初からあることの補足行（連番バッジ無しの字下げ行）。
    expect(find.text(_t('25マス_一覧_使い方_標準シート')), findsOneWidget);
    expect(find.text('Nhấn vào một dòng để mở bảng'), findsOneWidget);
    expect(find.text('Vuốt sang trái để xóa'), findsOneWidget);
  });

  testWidgets('一覧のセットを左スワイプすると確認の上で削除できる', (tester) async {
    await _createBoard(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    final created = (await ThinkingMatrixService().loadAll()).first;
    expect(find.text(created.title), findsOneWidget);

    await tester.drag(find.text(created.title), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // 確認ダイアログでキャンセルすると消えない。
    expect(find.text(_t('削除しますか？')), findsOneWidget);
    await tester.tap(find.text(_t('キャンセル')));
    await tester.pumpAndSettle();
    expect(find.text(created.title), findsOneWidget);
    expect(await ThinkingMatrixService().loadAll(), hasLength(1));

    await tester.drag(find.text(created.title), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('削除')));
    await tester.pumpAndSettle();

    expect(find.text(created.title), findsNothing);
    expect(find.text(_t('25マス_一覧が空です')), findsOneWidget);
    expect(await ThinkingMatrixService().loadAll(), isEmpty);
  });

  testWidgets('システムセット（日常等）の一覧タイルは、キーワード達成率ではなく'
      '拡充度%（ダッシュボードの拡充度と同じ計算式）を表示する（Step 5）', (tester) async {
    final service = ThinkingMatrixService();
    await service.ensureSystemPresets();
    final daily = (await service.loadAll()).firstWhere(
      (s) => s.id == ThinkingMatrixService.systemSetIds[TopicCategory.daily],
    );
    await service.upsertCellLayer2(
      setId: daily.id,
      themeId: daily.themes.first.id,
      columnId: daily.columns.first.id,
      keyword: 'テスト',
    );

    // システムセットが既にあるため、入口タップで（カテゴリ選択を経由せず）
    // 直接一覧が開く。
    await _openLayer2ThinkingMatrix(tester);

    // (1/3)/25*100 ≈ 1.3%（Step 2・Step 4のダッシュボードと同じ計算式）。
    expect(
      find.text('25マス_拡充度_一覧'.trFmt(_lang, ['1.3%'])),
      findsOneWidget,
    );
    // 従来のキーワード達成率表示（達成率 n% (filled/total)）はシステム
    // セットには出ない。
    expect(
      find.text('25マス_達成率'.trFmt(_lang, ['4', '1', '25'])),
      findsNothing,
    );
  });

  testWidgets('オリジナル・追加セットの一覧タイルは、従来どおりキーワード達成率のまま', (
    tester,
  ) async {
    await _createBoard(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // オリジナルは0/25埋まり（0%）のまま。拡充度表示ではなく従来の
    // 達成率表示が出る。
    expect(
      find.text('25マス_達成率'.trFmt(_lang, ['0', '0', '25'])),
      findsOneWidget,
    );
  });

  testWidgets('セルをタップしてキーワードを保存するとマスに表示され、再オープンで既存値が入る', (tester) async {
    await _createBoard(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('${_themeNames.first} × ${_t('時間')}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '海老名SAのメロンパン');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    expect(find.text('海老名SAのメロンパン'), findsOneWidget);
    // 埋まった1マス分、「＋」は24個に減る。
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(24));

    // 同じマスを再度開くと、既存のキーワードがTextFieldに入っている。
    await tester.tap(find.text('海老名SAのメロンパン'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '海老名SAのメロンパン');
    await tester.tap(find.text(_t('キャンセル')));
    await tester.pumpAndSettle();
  });

  testWidgets('レイヤーⅡのセルシートには「1分話した」トグルもタイマーも無い', (tester) async {
    await _createBoard(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text(_t('1分話した')), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.text(_t('開始する')), findsNothing);
    // レイヤーⅢ用のPREP欄・60秒スピーチもⅡには無い。
    expect(find.text(_t('結論')), findsNothing);
    expect(find.text(_t('母語で60秒スピーチ')), findsNothing);

    await tester.enterText(find.byType(TextField), '海老名SAのメロンパン');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    expect(find.text('海老名SAのメロンパン'), findsOneWidget);
    final sets = await ThinkingMatrixService().loadAll();
    expect(
      sets.first.cellFor(sets.first.themes.first.id, 'time').status,
      ThinkingMatrixCellStatus.filled,
    );
  });

  testWidgets('1行をキーワードだけで埋めるとトロフィー1つ（レイヤーⅡはspokenを持たないため2つにはならない）', (
    tester,
  ) async {
    await _createBoard(tester);
    final created = (await ThinkingMatrixService().loadAll()).first;
    final firstTheme = created.themes.first;
    final service = ThinkingMatrixService();

    for (final column in created.columns) {
      await service.upsertCellLayer2(
        setId: created.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
      );
    }
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();

    // filledの行はトロフィー1つ。他の行・列は空なので見えているトロフィーは
    // この1行分の1つだけ（upsertCellLayer2はstatusをempty/filledのみに
    // するため、2つ目のトロフィーになりようがない）。
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });

  testWidgets('シチュエーション（3マスで行ビンゴ）でもトロフィーは1つのまま', (tester) async {
    await _openLayer2ThinkingMatrix(tester);
    await tester.tap(find.text(_t('シチュエーション')));
    await tester.pumpAndSettle();
    final created = (await ThinkingMatrixService().loadAll()).first;
    final firstTheme = created.themes.first;
    expect(created.columns, hasLength(3));
    final service = ThinkingMatrixService();

    for (final column in created.columns) {
      await service.upsertCellLayer2(
        setId: created.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
      );
    }
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });

  testWidgets('シチュエーション（15マス）も最後の1マスを埋めるとコンプリートダイアログが出て落ちない', (
    tester,
  ) async {
    await _openLayer2ThinkingMatrix(tester);
    await tester.tap(find.text(_t('シチュエーション')));
    await tester.pumpAndSettle();
    final created = (await ThinkingMatrixService().loadAll()).first;
    final lastTheme = created.themes.last;

    await _fillAllExceptOne(
      created.id,
      skipThemeId: lastTheme.id,
      skipColumnId: created.columns.first.id,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ラストキーワード');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('25マス_コンプリート_本文'.trFmt(_lang, ['15'])),
      findsOneWidget,
    );
    await tester.tap(find.text(_t('OK')));
    await tester.pumpAndSettle();

    final completed = await ThinkingMatrixService().loadById(created.id);
    expect(completed!.completedAt, isNotNull);
    expect(completed.totalCells, 15);
  });

  testWidgets('キーワードを空にして保存すると＋に戻る', (tester) async {
    await _createBoard(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '海老名SAのメロンパン');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(24));

    await tester.tap(find.text('海老名SAのメロンパン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text(_t('マスを埋める')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_rounded), findsNWidgets(25));

    final sets = await ThinkingMatrixService().loadAll();
    expect(sets.first.filledCount, 0);
  });

  testWidgets(
    '25マス目を埋めると列バッジとコンプリートダイアログが出て、再訪や再コンプリートでは出ない',
    (tester) async {
      await _createBoard(tester);
      final created = (await ThinkingMatrixService().loadAll()).first;
      final lastTheme = created.themes.last;

      await _fillAllExceptOne(
        created.id,
        skipThemeId: lastTheme.id,
        skipColumnId: 'time',
      );

      // 一覧を経由してボードを開き直し、Serviceで直接埋めた24マスを反映させる。
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(created.title));
      await tester.pumpAndSettle();

      // 残り1マスだけがempty。
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ラストキーワード');
      await tester.tap(find.text(_t('マスを埋める')));
      await tester.pumpAndSettle();

      // _fillAllExceptOneは最後の1マス以外の24マスをセットアップ時点で
      // 既に埋めているため、最後の1マスを埋めると5列（列ヘッダー上）と
      // 5行（ネタ名の左）の両方がマスター済みになり、アイコンが10個揃う。
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(10));
      // 25マス目でコンプリートダイアログが出る。
      expect(find.text(_t('25マスコンプリート')), findsOneWidget);
      await tester.tap(find.text(_t('OK')));
      await tester.pumpAndSettle();

      final completedSets = await ThinkingMatrixService().loadAll();
      expect(completedSets.first.completedAt, isNotNull);

      // 一覧を経由して同じセットを開き直しても、ダイアログは再表示されない。
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(created.title));
      await tester.pumpAndSettle();
      expect(find.text(_t('25マスコンプリート')), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(10));

      // 1マス消して24/25にしてから再度埋め直しても、初回のcompletedAtは残り
      // ダイアログは再表示されない（再祝いはしない）。
      final firstCompletedAt = completedSets.first.completedAt;
      await tester.tap(find.text('ラストキーワード'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text(_t('マスを埋める')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ラストキーワード');
      await tester.tap(find.text(_t('マスを埋める')));
      await tester.pumpAndSettle();

      expect(find.text(_t('25マスコンプリート')), findsNothing);
      final recompletedSets = await ThinkingMatrixService().loadAll();
      expect(recompletedSets.first.completedAt, firstCompletedAt);
    },
  );

  testWidgets('ボード見出しをタップしてセットタイトルをインライン編集できる', (tester) async {
    await _createBoard(tester);
    final created = (await ThinkingMatrixService().loadAll()).first;

    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();
    expect(find.text(_t('25マス_タイトル編集')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新しいタイトル');
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    expect(find.text('新しいタイトル'), findsOneWidget);
    final updated = await ThinkingMatrixService().loadById(created.id);
    expect(updated!.title, '新しいタイトル');
  });

  testWidgets('テーマ編集シートはキーボード表示時（テーマ5欄）でもオーバーフローしない（回帰）', (
    tester,
  ) async {
    await _createBoard(tester);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    expect(find.text(_t('テーマ')), findsOneWidget);

    // キーボード表示時と同じだけ画面下端を圧迫する
    // （ネタ5欄はTextEditSheet等の1〜数欄シートより高さを食うため、
    // SingleChildScrollViewが無いとRenderFlexがオーバーフローしていた）。
    final view = tester.view;
    addTearDown(view.resetViewInsets);
    view.viewInsets = FakeViewPadding(bottom: 320 * view.devicePixelRatio);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 一番下のフィールド・保存ボタンまでスクロールで到達できる。
    await tester.scrollUntilVisible(
      find.text(_t('保存')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(_t('保存')), findsOneWidget);
  });

  testWidgets('セルのキーワード入力シートはキーボード表示時でもオーバーフローしない（回帰）', (
    tester,
  ) async {
    await _createBoard(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(_t('マスを埋める')), findsOneWidget);

    // キーワード欄・タイマー行・トグル・ボタンに加えてキーボードが乗ると
    // オーバーフローしていた（SingleChildScrollView追加前の回帰）。
    final view = tester.view;
    addTearDown(view.resetViewInsets);
    view.viewInsets = FakeViewPadding(bottom: 320 * view.devicePixelRatio);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text(_t('マスを埋める')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(_t('マスを埋める')), findsOneWidget);
  });

  testWidgets('列がマスターになってアイコンが増えても、盤面の位置はずれない（アイコン用スペースを常に確保）', (
    tester,
  ) async {
    await _createBoard(tester);
    final created = (await ThinkingMatrixService().loadAll()).first;

    // マスターアイコンが1つも無い状態での「理由」列見出しの位置。
    final positionBefore = tester.getTopLeft(find.text(_t('理由')));
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

    // 「時間」列（マスターにする列とは別の列）をServiceで直接埋める。
    final service = ThinkingMatrixService();
    for (final theme in created.themes) {
      await service.upsertCellLayer2(
        setId: created.id,
        themeId: theme.id,
        columnId: 'time',
        keyword: 'キーワード',
      );
    }

    // 一覧を経由してボードを開き直し、マスター済みの状態を反映させる。
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    final positionAfter = tester.getTopLeft(find.text(_t('理由')));
    expect(positionAfter, positionBefore);
  });

  testWidgets('1テーマ分（横1行）が5列すべて埋まると、テーマ名の左にマスターアイコンが出る', (
    tester,
  ) async {
    await _createBoard(tester);
    final created = (await ThinkingMatrixService().loadAll()).first;
    final firstTheme = created.themes.first;

    // 縦方向の1行（同じテーマの5列）だけをServiceで直接埋める。
    // 列は1つも揃わないので、列ヘッダー側のアイコンは出ない。
    final service = ThinkingMatrixService();
    for (final column in created.columns) {
      await service.upsertCellLayer2(
        setId: created.id,
        themeId: firstTheme.id,
        columnId: column.id,
        keyword: 'キーワード',
      );
    }

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(created.title));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });
}
