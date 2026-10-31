import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/data/thinking_matrix_presets.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/thinking_matrix_cell.dart';
import 'package:osm_gradus/models/thinking_matrix_cell_status.dart';
import 'package:osm_gradus/models/thinking_matrix_set.dart';
import 'package:osm_gradus/models/thinking_theme.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/thinking_matrix_service.dart';
import 'package:osm_gradus/widgets/thinking_matrix_cell_sheet.dart' show themeDisplayName;

const _themeNames = ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('createSetでテーマ5・汎用5列・マス25・全部emptyのオリジナルセットができる', () async {
    final service = ThinkingMatrixService();
    final set = await service.createSet(
      title: 'セット1',
      themeNames: _themeNames,
    );

    expect(set.category, isNull);
    expect(set.themes.length, 5);
    expect(set.columns.map((c) => c.id), ['time', 'view', 'compare', 'scale', 'reason']);
    expect(set.cells.length, 25);
    expect(set.totalCells, 25);
    expect(
      set.cells.every((c) => c.status == ThinkingMatrixCellStatus.empty),
      isTrue,
    );
    expect(set.filledCount, 0);
    expect(set.completionRatio, 0);
    expect(set.completedAt, isNull);
  });

  test('6個目のテーマでcreateSetすると明示エラーになる', () async {
    final service = ThinkingMatrixService();
    expect(
      () => service.createSet(
        title: 'セット1',
        themeNames: [..._themeNames, 'おまけ'],
      ),
      throwsArgumentError,
    );
  });

  test('ThinkingMatrixSet.create()もテーマが5つでない場合はassertで落ちる', () {
    expect(
      () => ThinkingMatrixSet.create(
        title: 'セット1',
        themes: _themeNames.take(4).map(ThinkingTheme.create).toList(),
        columns: ThinkingMatrixPresets.generalColumns,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('createFromPresetのcategoryにrandomを渡すと明示エラーになる', () async {
    final service = ThinkingMatrixService();
    expect(
      () => service.createFromPreset(TopicCategory.random, title: 'セット1'),
      throwsArgumentError,
    );
  });

  group('createFromPreset', () {
    test('日常プリセット: 列5・行5・マス25、テーマが趣味…季節', () async {
      final service = ThinkingMatrixService();
      final set = await service.createFromPreset(
        TopicCategory.daily,
        title: '日常セット',
      );

      expect(set.category, TopicCategory.daily);
      expect(set.columns.map((c) => c.id), ['time', 'view', 'compare', 'scale', 'reason']);
      expect(set.themes.map((t) => t.name), ['趣味', '健康', '買い物', '旅行', '季節']);
      expect(set.cells.length, 25);
      expect(set.totalCells, 25);
    });

    test('ビジネスプリセット: 汎用5列、テーマが時間…問題', () async {
      final service = ThinkingMatrixService();
      final set = await service.createFromPreset(
        TopicCategory.business,
        title: 'ビジネスセット',
      );

      expect(set.category, TopicCategory.business);
      expect(set.columns.map((c) => c.id), ['time', 'view', 'compare', 'scale', 'reason']);
      expect(set.themes.map((t) => t.name), ['時間', 'チーム', '成長', '仕事', '問題']);
    });

    test('シチュエーション: 列3（職場・学校・病院）・マス15', () async {
      final service = ThinkingMatrixService();
      final set = await service.createFromPreset(
        TopicCategory.situational,
        title: 'シチュエーションセット',
      );

      expect(set.category, TopicCategory.situational);
      expect(set.columns.map((c) => c.id), ['workplace', 'school', 'hospital']);
      expect(set.themes.map((t) => t.name), ['相談', '依頼', '断り', '謝罪', '提案']);
      expect(set.cells.length, 15);
      expect(set.totalCells, 15);
    });
  });

  group('ensureSystemPresets（Step 1: 拡充度母数65マスの自動シード）', () {
    test('クリーンなprefsで呼ぶと、日常・ビジネス・シチュエーションが安定IDで'
        '作成され、合計65マス（25+25+15）になる', () async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();

      final all = await service.loadAll();
      final system = {
        for (final id in ThinkingMatrixService.systemSetIds.values)
          id: all.firstWhere((s) => s.id == id),
      };
      expect(system, hasLength(3));
      expect(
        system[ThinkingMatrixService.systemSetIds[TopicCategory.daily]]!
            .category,
        TopicCategory.daily,
      );
      expect(
        system[ThinkingMatrixService.systemSetIds[TopicCategory.business]]!
            .category,
        TopicCategory.business,
      );
      expect(
        system[ThinkingMatrixService.systemSetIds[TopicCategory.situational]]!
            .category,
        TopicCategory.situational,
      );
      final totalCells = system.values
          .map((s) => s.totalCells)
          .reduce((a, b) => a + b);
      expect(totalCells, 65);
      expect(
        system.values.every(
          (s) => s.cells.every(
            (c) => c.status == ThinkingMatrixCellStatus.empty,
          ),
        ),
        isTrue,
      );
    });

    test('タイトルはカテゴリ名そのもので、既存の自動採番「セットN」と衝突しない', () async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();

      final all = await service.loadAll();
      final dailySet = all.firstWhere(
        (s) => s.id == ThinkingMatrixService.systemSetIds[TopicCategory.daily],
      );
      expect(dailySet.title, '日常'.tr(appSettings.language));
      expect(dailySet.title, isNot(startsWith('セット')));
    });

    test('2回目に呼んでも増殖しない（冪等）', () async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();
      await service.ensureSystemPresets();

      final all = await service.loadAll();
      final systemCount = all
          .where((s) => ThinkingMatrixService.systemSetIds.values.contains(s.id))
          .length;
      expect(systemCount, 3);
    });

    test('既存のユーザー作成セットは消えない', () async {
      final service = ThinkingMatrixService();
      final userSet = await service.createSet(
        title: 'ユーザーのセット',
        themeNames: _themeNames,
      );
      await service.ensureSystemPresets();

      final all = await service.loadAll();
      expect(all.any((s) => s.id == userSet.id), isTrue);
      expect(all, hasLength(4));
    });

    test('既にシステムセットが進捗を持っていても中身を書き換えない', () async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();
      final dailyId = ThinkingMatrixService.systemSetIds[TopicCategory.daily]!;
      final daily = (await service.loadAll()).firstWhere(
        (s) => s.id == dailyId,
      );
      final themeId = daily.themes.first.id;
      final columnId = daily.columns.first.id;
      await service.upsertCellLayer2(
        setId: dailyId,
        themeId: themeId,
        columnId: columnId,
        keyword: '進めた記録',
      );

      await service.ensureSystemPresets();

      final updated = (await service.loadAll()).firstWhere(
        (s) => s.id == dailyId,
      );
      expect(updated.cellFor(themeId, columnId).keyword, '進めた記録');
    });

    test('システムセットが削除された後に呼ぶと、空の新規セットとして再生成される'
        '（削除前の進捗は戻らない）', () async {
      final service = ThinkingMatrixService();
      await service.ensureSystemPresets();
      final dailyId = ThinkingMatrixService.systemSetIds[TopicCategory.daily]!;
      final daily = (await service.loadAll()).firstWhere(
        (s) => s.id == dailyId,
      );
      await service.upsertCellLayer2(
        setId: dailyId,
        themeId: daily.themes.first.id,
        columnId: daily.columns.first.id,
        keyword: '消える記録',
      );
      await service.delete(dailyId);

      await service.ensureSystemPresets();

      final regenerated = (await service.loadAll()).firstWhere(
        (s) => s.id == dailyId,
      );
      expect(
        regenerated.cells.every((c) => c.status == ThinkingMatrixCellStatus.empty),
        isTrue,
      );
    });

    test('システムIDのセットがプリセットと食い違う壊れた状態（列数不一致）でも、'
        'ensureSystemPresetsは中身を修復しない（IDがあれば何もしない方針）', () async {
      final service = ThinkingMatrixService();
      final dailyId = ThinkingMatrixService.systemSetIds[TopicCategory.daily]!;
      // シチュエーション用の3列プリセットを、あえて日常IDで保存する
      // （列数25→15への食い違いを人工的に作る）。
      final corrupted = ThinkingMatrixSet.create(
        id: dailyId,
        title: '壊れた日常',
        category: TopicCategory.daily,
        themes: ThinkingMatrixPresets.themesFor(
          TopicCategory.situational,
        ).map(ThinkingTheme.create).toList(),
        columns: ThinkingMatrixPresets.columnsFor(TopicCategory.situational),
      );
      await service.save(corrupted);

      await service.ensureSystemPresets();

      final all = await service.loadAll();
      final daily = all.firstWhere((s) => s.id == dailyId);
      // 修復されず、壊れたタイトル・列数（15マス）のまま残る。
      expect(daily.title, '壊れた日常');
      expect(daily.totalCells, 15);
    });

    test('オリジナル／追加の同カテゴリセットは対象外（systemSetIdsに含まれない）', () async {
      final service = ThinkingMatrixService();
      final extraDaily = await service.createFromPreset(
        TopicCategory.daily,
        title: '追加の日常セット',
      );
      await service.ensureSystemPresets();

      final all = await service.loadAll();
      expect(all.any((s) => s.id == extraDaily.id), isTrue);
      expect(
        ThinkingMatrixService.systemSetIds.values.contains(extraDaily.id),
        isFalse,
      );
    });
  });

  test('upsertCellLayer2でfilled/空へ戻せる。statusはempty/filledのみ', () async {
    final service = ThinkingMatrixService();
    final created = await service.createSet(
      title: 'セット1',
      themeNames: _themeNames,
    );
    final themeId = created.themes.first.id;

    final filled = await service.upsertCellLayer2(
      setId: created.id,
      themeId: themeId,
      columnId: 'time',
      keyword: '海老名SAのメロンパン',
    );
    final filledCell = filled.cellFor(themeId, 'time');
    expect(filledCell.status, ThinkingMatrixCellStatus.filled);
    expect(filledCell.keyword, '海老名SAのメロンパン');

    final emptied = await service.upsertCellLayer2(
      setId: created.id,
      themeId: themeId,
      columnId: 'time',
      keyword: '  ',
    );
    final emptyCell = emptied.cellFor(themeId, 'time');
    expect(emptyCell.status, ThinkingMatrixCellStatus.empty);
    expect(emptyCell.keyword, '');
  });

  test('行（1テーマ5列）が揃うとisRowFilledがtrueになる', () async {
    final service = ThinkingMatrixService();
    var set = await service.createSet(title: 'セット1', themeNames: _themeNames);
    final themeId = set.themes.first.id;

    for (final column in set.columns) {
      set = await service.upsertCellLayer2(
        setId: set.id,
        themeId: themeId,
        columnId: column.id,
        keyword: 'キーワード',
      );
    }

    expect(set.isRowFilled(0), isTrue);
    expect(set.isRowFilled(1), isFalse);
  });

  test('列（1列5テーマ）が揃うとisColumnFilled/completedColumnIdsに乗る', () async {
    final service = ThinkingMatrixService();
    var set = await service.createSet(title: 'セット1', themeNames: _themeNames);

    for (final theme in set.themes) {
      set = await service.upsertCellLayer2(
        setId: set.id,
        themeId: theme.id,
        columnId: 'compare',
        keyword: 'キーワード',
      );
    }

    expect(set.isColumnFilled('compare'), isTrue);
    expect(set.completedColumnIds, ['compare']);
    expect(set.isColumnFilled('time'), isFalse);
  });

  group('trophyTierForRow / trophyTierForColumn', () {
    test('キーワードのみ→1、PREPまで→2、PREP+60秒スピーチまで→4', () async {
      final service = ThinkingMatrixService();
      var set = await service.createSet(title: 'セット1', themeNames: _themeNames);
      final themeId = set.themes.first.id;

      expect(set.trophyTierForRow(0), 0);

      for (final column in set.columns) {
        set = await service.upsertCellLayer2(
          setId: set.id,
          themeId: themeId,
          columnId: column.id,
          keyword: 'キーワード',
        );
      }
      expect(set.trophyTierForRow(0), 1);
      expect(set.trophyTierForRow(1), 0);

      for (final column in set.columns) {
        set = await service.upsertCellLayer3(
          setId: set.id,
          themeId: themeId,
          columnId: column.id,
          keyword: 'キーワード',
          conclusion: '結論',
          reason: '理由',
          example: '具体例',
        );
      }
      expect(set.trophyTierForRow(0), 2);

      for (final column in set.columns) {
        set = await service.upsertCellLayer3(
          setId: set.id,
          themeId: themeId,
          columnId: column.id,
          keyword: 'キーワード',
          conclusion: '結論',
          reason: '理由',
          example: '具体例',
          speech60Done: true,
        );
      }
      expect(set.trophyTierForRow(0), 4);
    });

    test('PREP未完了でも60秒スピーチだけ全マス揃えば3（PREPのみ揃った2より高い）', () async {
      final service = ThinkingMatrixService();
      var set = await service.createSet(title: 'セット1', themeNames: _themeNames);
      final themeId = set.themes.first.id;

      for (final column in set.columns) {
        set = await service.upsertCellLayer3(
          setId: set.id,
          themeId: themeId,
          columnId: column.id,
          keyword: 'キーワード',
          speech60Done: true,
          // PREP（結論・理由・例示）は空のまま。
        );
      }
      expect(set.trophyTierForRow(0), 3);
    });

    test('列も行と同じ0〜4段階になる', () async {
      final service = ThinkingMatrixService();
      var set = await service.createSet(title: 'セット1', themeNames: _themeNames);

      expect(set.trophyTierForColumn('time'), 0);

      for (final theme in set.themes) {
        set = await service.upsertCellLayer3(
          setId: set.id,
          themeId: theme.id,
          columnId: 'time',
          keyword: 'キーワード',
          conclusion: '結論',
          reason: '理由',
          example: '具体例',
          speech60Done: true,
        );
      }
      expect(set.trophyTierForColumn('time'), 4);
      expect(set.trophyTierForColumn('compare'), 0);
    });

    test('PREPが1項目でも空なら段階1のまま（キーワードのみ扱い）', () async {
      final service = ThinkingMatrixService();
      var set = await service.createSet(title: 'セット1', themeNames: _themeNames);
      final themeId = set.themes.first.id;

      for (final column in set.columns) {
        set = await service.upsertCellLayer3(
          setId: set.id,
          themeId: themeId,
          columnId: column.id,
          keyword: 'キーワード',
          conclusion: '結論',
          reason: '理由',
          // exampleを空のままにする。
        );
      }
      expect(set.trophyTierForRow(0), 1);
    });
  });

  test('upsertCellLayer3でキーワードを空にするとPREP・60秒スピーチも一緒にクリアされる', () async {
    final service = ThinkingMatrixService();
    final created = await service.createFromPreset(
      TopicCategory.business,
      title: 'セット1',
    );
    final themeId = created.themes.first.id;

    var set = await service.upsertCellLayer3(
      setId: created.id,
      themeId: themeId,
      columnId: 'time',
      keyword: 'キーワード',
      conclusion: '結論',
      reason: '理由',
      example: '具体例',
      speech60Done: true,
    );
    expect(set.isCellPrepComplete(set.cellFor(themeId, 'time')), isTrue);

    set = await service.upsertCellLayer3(
      setId: created.id,
      themeId: themeId,
      columnId: 'time',
      keyword: '  ',
      conclusion: '結論',
      reason: '理由',
      example: '具体例',
      speech60Done: true,
    );
    final cleared = set.cellFor(themeId, 'time');
    expect(cleared.status, ThinkingMatrixCellStatus.empty);
    expect(cleared.conclusion, '');
    expect(cleared.reason, '');
    expect(cleared.example, '');
    expect(cleared.speech60Done, isFalse);
  });

  test('全マス埋めるとcompletedAtが入り、1マス消して再保存しても残り続ける', () async {
    final service = ThinkingMatrixService();
    var set = await service.createSet(title: 'セット1', themeNames: _themeNames);

    for (final theme in set.themes) {
      for (final column in set.columns) {
        set = await service.upsertCellLayer2(
          setId: set.id,
          themeId: theme.id,
          columnId: column.id,
          keyword: 'キーワード',
        );
      }
    }

    expect(set.filledCount, set.totalCells);
    expect(set.completionRatio, 1.0);
    expect(set.completedAt, isNotNull);
    final firstCompletedAt = set.completedAt;

    final firstTheme = set.themes.first;
    set = await service.upsertCellLayer2(
      setId: set.id,
      themeId: firstTheme.id,
      columnId: 'time',
      keyword: '',
    );
    expect(set.filledCount, set.totalCells - 1);
    expect(set.completedAt, firstCompletedAt);

    // 再度埋め直しても、初回コンプリート日時は上書きされない。
    set = await service.upsertCellLayer2(
      setId: set.id,
      themeId: firstTheme.id,
      columnId: 'time',
      keyword: 'キーワード',
    );
    expect(set.filledCount, set.totalCells);
    expect(set.completedAt, firstCompletedAt);
  });

  test('toJson/fromJsonで全フィールド（PREP・60秒スピーチ含む）が往復する', () async {
    final service = ThinkingMatrixService();
    final created = await service.createFromPreset(
      TopicCategory.business,
      title: 'セット1',
    );
    final withCell = await service.upsertCellLayer3(
      setId: created.id,
      themeId: created.themes.first.id,
      columnId: 'scale',
      keyword: 'ミクロな話',
      conclusion: '結論です',
      reason: '理由です',
      example: '具体例です',
      speech60Done: true,
    );

    final restored = ThinkingMatrixSet.fromJson(withCell.toJson());

    expect(restored.id, withCell.id);
    expect(restored.title, withCell.title);
    expect(restored.category, TopicCategory.business);
    expect(restored.columns.map((c) => c.id), withCell.columns.map((c) => c.id));
    expect(restored.themes.map((t) => t.id), withCell.themes.map((t) => t.id));
    expect(restored.themes.map((t) => t.name), withCell.themes.map((t) => t.name));
    expect(restored.cells.length, withCell.cells.length);
    expect(restored.completedAt, withCell.completedAt);
    final restoredCell = restored.cellFor(created.themes.first.id, 'scale');
    expect(restoredCell.keyword, 'ミクロな話');
    expect(restoredCell.status, ThinkingMatrixCellStatus.filled);
    expect(restoredCell.conclusion, '結論です');
    expect(restoredCell.reason, '理由です');
    expect(restoredCell.example, '具体例です');
    expect(restoredCell.speech60Done, isTrue);
  });

  test('旧フィールド（conclusion/reason/example/speech60Done無し）のJSONも既定値で読める', () {
    final now = DateTime.now().toIso8601String();
    final json = {
      'themeId': 'theme-1',
      'columnId': 'time',
      'keyword': 'キーワード',
      'status': 'filled',
      'updatedAt': now,
    };
    final cell = ThinkingMatrixCell.fromJson(json);
    expect(cell.conclusion, '');
    expect(cell.reason, '');
    expect(cell.example, '');
    expect(cell.speech60Done, isFalse);
  });

  test('旧status: "spoken"のセルJSONはfilledに正規化して読める', () {
    final now = DateTime.now().toIso8601String();
    final json = {
      'themeId': 'theme-1',
      'columnId': 'time',
      'keyword': 'キーワード',
      'status': 'spoken',
      'updatedAt': now,
    };
    final cell = ThinkingMatrixCell.fromJson(json);
    expect(cell.status, ThinkingMatrixCellStatus.filled);
  });

  test('セルが不足した壊れたJSONを読んでも不足分がemptyで補われる', () {
    final now = DateTime.now().toIso8601String();
    final themes = _themeNames
        .map(ThinkingTheme.create)
        .map((t) => t.toJson())
        .toList();
    final json = {
      'id': 'tm_broken',
      'title': '壊れたセット',
      'themes': themes,
      'cells': <Map<String, dynamic>>[],
      'createdAt': now,
      'updatedAt': now,
    };

    final restored = ThinkingMatrixSet.fromJson(json);

    expect(restored.cells.length, 25);
    expect(
      restored.cells.every((c) => c.status == ThinkingMatrixCellStatus.empty),
      isTrue,
    );
  });

  test(
    '旧JSON（netas/netaId/perspective: stance|change、category無し）が'
    'themes + オリジナル + 新汎用5列で読める。スタンス列のキーワードはview列、'
    '変化列はreason列に残る（旧status: spokenもfilledに正規化される）',
    () {
      final now = DateTime.now().toIso8601String();
      final legacyThemes = _themeNames
          .map(ThinkingTheme.create)
          .map((t) => t.toJson())
          .toList();
      final firstThemeId = legacyThemes.first['id'] as String;
      final json = {
        'id': 'tm_legacy',
        'title': '旧セット',
        'netas': legacyThemes,
        'cells': [
          {
            'netaId': firstThemeId,
            'perspective': 'stance',
            'keyword': '立場のキーワード',
            'status': 'filled',
            'updatedAt': now,
          },
          {
            'netaId': firstThemeId,
            'perspective': 'change',
            'keyword': '変化のキーワード',
            'status': 'spoken',
            'updatedAt': now,
          },
          {
            'netaId': firstThemeId,
            'perspective': 'time',
            'keyword': '時間のキーワード',
            'status': 'filled',
            'updatedAt': now,
          },
        ],
        'createdAt': now,
        'updatedAt': now,
      };

      final restored = ThinkingMatrixSet.fromJson(json);

      expect(restored.category, isNull);
      expect(restored.columns.map((c) => c.id), ['time', 'view', 'compare', 'scale', 'reason']);
      expect(restored.themes.map((t) => t.id), legacyThemes.map((t) => t['id']));
      expect(restored.cellFor(firstThemeId, 'view').keyword, '立場のキーワード');
      expect(restored.cellFor(firstThemeId, 'reason').keyword, '変化のキーワード');
      expect(restored.cellFor(firstThemeId, 'reason').status, ThinkingMatrixCellStatus.filled);
      expect(restored.cellFor(firstThemeId, 'time').keyword, '時間のキーワード');
    },
  );

  test('旧JSONのcategory storageKey（英語）は対応するTopicCategoryへマップされる', () {
    final now = DateTime.now().toIso8601String();
    final themes = _themeNames
        .map(ThinkingTheme.create)
        .map((t) => t.toJson())
        .toList();
    final json = {
      'id': 'tm_legacy_category',
      'title': '旧カテゴリセット',
      'category': 'daily',
      'themes': themes,
      'cells': <Map<String, dynamic>>[],
      'createdAt': now,
      'updatedAt': now,
    };

    final restored = ThinkingMatrixSet.fromJson(json);

    expect(restored.category, TopicCategory.daily);
    expect(restored.columns.map((c) => c.id), ['time', 'view', 'compare', 'scale', 'reason']);
  });

  test('category="ランダム"・不明な値・"original"はすべてオリジナル（null）扱い', () {
    final now = DateTime.now().toIso8601String();
    for (final rawCategory in ['ランダム', 'random', 'unknown', 'original']) {
      final themes = _themeNames
          .map(ThinkingTheme.create)
          .map((t) => t.toJson())
          .toList();
      final json = {
        'id': 'tm_$rawCategory',
        'title': 'テスト',
        'category': rawCategory,
        'themes': themes,
        'cells': <Map<String, dynamic>>[],
        'createdAt': now,
        'updatedAt': now,
      };
      expect(ThinkingMatrixSet.fromJson(json).category, isNull, reason: rawCategory);
    }
  });

  test('prefsに保存したものを新しいServiceインスタンスで読める', () async {
    final service = ThinkingMatrixService();
    final created = await service.createSet(
      title: 'セット1',
      themeNames: _themeNames,
    );

    final reloadedService = ThinkingMatrixService();
    final reloaded = await reloadedService.loadById(created.id);

    expect(reloaded, isNotNull);
    expect(reloaded!.title, 'セット1');
    expect(reloaded.themes.length, 5);
    expect(reloaded.cells.length, 25);
  });

  test('renameSetとupdateThemeNameでテーマ名を変えてもキーワードは残る', () async {
    final service = ThinkingMatrixService();
    var set = await service.createSet(title: 'セット1', themeNames: _themeNames);
    final themeId = set.themes.first.id;
    set = await service.upsertCellLayer2(
      setId: set.id,
      themeId: themeId,
      columnId: 'reason',
      keyword: 'きっかけの話',
    );

    set = await service.renameSet(set.id, 'マイセット');
    expect(set.title, 'マイセット');

    set = await service.updateThemeName(set.id, themeId, '新しいテーマ名');
    final renamedTheme = set.themes.firstWhere((t) => t.id == themeId);
    expect(renamedTheme.name, '新しいテーマ名');
    expect(set.cellFor(themeId, 'reason').keyword, 'きっかけの話');
  });

  test('deleteとclearAllでセットが消える', () async {
    final service = ThinkingMatrixService();
    final a = await service.createSet(title: 'A', themeNames: _themeNames);
    await service.createSet(title: 'B', themeNames: _themeNames);

    await service.delete(a.id);
    var all = await service.loadAll();
    expect(all.length, 1);
    expect(all.first.title, 'B');

    await service.clearAll();
    all = await service.loadAll();
    expect(all, isEmpty);
  });

  group('themeDisplayName', () {
    test('プリセット（categoryあり）のテーマ名はl10nキーとして言語切替で訳される', () async {
      final service = ThinkingMatrixService();
      final set = await service.createFromPreset(
        TopicCategory.daily,
        title: 'セット1',
      );
      final theme = set.themes.first;
      expect(theme.name, '趣味');

      expect(themeDisplayName(set, theme, 'ja'), '趣味');
      expect(themeDisplayName(set, theme, 'en'), 'Hobby');
      expect(themeDisplayName(set, theme, 'vi'), 'Sở thích');
    });

    test('オリジナル（categoryなし）の自由入力テーマ名は、偶然プリセット名と一致しても訳さない', () async {
      final service = ThinkingMatrixService();
      // 「旅行」は日常プリセットのテーマ名と偶然一致するが、このセットは
      // オリジナル（category: null）なので原文のまま表示する。
      final set = await service.createSet(
        title: 'セット1',
        themeNames: ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'],
      );
      final theme = set.themes.firstWhere((t) => t.name == '旅行');

      expect(themeDisplayName(set, theme, 'vi'), '旅行');
    });

    test('プリセットのテーマ名をユーザーが改名すると、以後は訳されず保存文字列のまま表示される', () async {
      final service = ThinkingMatrixService();
      final created = await service.createFromPreset(
        TopicCategory.daily,
        title: 'セット1',
      );
      final themeId = created.themes.first.id;

      final renamed = await service.updateThemeName(
        created.id,
        themeId,
        'カスタムテーマ名',
      );
      final theme = renamed.themes.firstWhere((t) => t.id == themeId);

      expect(themeDisplayName(renamed, theme, 'vi'), 'カスタムテーマ名');
    });
  });
}
