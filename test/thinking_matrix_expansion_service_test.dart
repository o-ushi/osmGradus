import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/thinking_matrix_presets.dart';
import 'package:osm_gradus/models/dashboard_summary.dart';
import 'package:osm_gradus/models/thinking_matrix_cell.dart';
import 'package:osm_gradus/models/thinking_matrix_set.dart';
import 'package:osm_gradus/models/thinking_theme.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/services/thinking_matrix_expansion_service.dart';
import 'package:osm_gradus/services/thinking_matrix_service.dart';

/// システムIDを持つ[category]のセットを、先頭から[speechDoneCount]マスを
/// 60秒スピーチ完了、続く[prepCompleteCount]マスをPREP完了、続く
/// [keywordOnlyCount]マスをキーワードのみにして組み立てる。残りは空のまま。
ThinkingMatrixSet _systemSet(
  TopicCategory category, {
  int speechDoneCount = 0,
  int prepCompleteCount = 0,
  int keywordOnlyCount = 0,
}) {
  final id = ThinkingMatrixService.systemSetIds[category]!;
  final base = ThinkingMatrixSet.create(
    id: id,
    title: category.storageKey,
    category: category,
    themes: ThinkingMatrixPresets.themesFor(
      category,
    ).map(ThinkingTheme.create).toList(),
    columns: ThinkingMatrixPresets.columnsFor(category),
  );
  final updatedCells = <ThinkingMatrixCell>[
    for (var i = 0; i < base.cells.length; i++)
      if (i < speechDoneCount)
        base.cells[i].copyWith(
          keyword: 'kw$i',
          conclusion: 'c',
          reason: 'r',
          example: 'e',
          speech60Done: true,
        )
      else if (i < speechDoneCount + prepCompleteCount)
        base.cells[i].copyWith(
          keyword: 'kw$i',
          conclusion: 'c',
          reason: 'r',
          example: 'e',
        )
      else if (i < speechDoneCount + prepCompleteCount + keywordOnlyCount)
        base.cells[i].copyWith(keyword: 'kw$i')
      else
        base.cells[i],
  ];
  return base.copyWith(cells: updatedCells);
}

void main() {
  group('ThinkingMatrixExpansionService.cellWeight', () {
    ThinkingMatrixCell emptyCell() => ThinkingMatrixCell.empty(
      themeId: 't',
      columnId: 'c',
      updatedAt: DateTime(2026, 1, 1),
    );

    test('未入力は0', () {
      final set = _systemSet(TopicCategory.daily);
      expect(
        ThinkingMatrixExpansionService.cellWeight(set, emptyCell()),
        0.0,
      );
    });

    test('キーワード入力済みは1/3', () {
      final set = _systemSet(TopicCategory.daily);
      final cell = emptyCell().copyWith(keyword: 'キーワード');
      expect(
        ThinkingMatrixExpansionService.cellWeight(set, cell),
        closeTo(1 / 3, 1e-9),
      );
    });

    test('PREP（結論・理由・具体例）まで入力済みは2/3', () {
      final set = _systemSet(TopicCategory.daily);
      final cell = emptyCell().copyWith(
        keyword: 'キーワード',
        conclusion: '結論',
        reason: '理由',
        example: '具体例',
      );
      expect(
        ThinkingMatrixExpansionService.cellWeight(set, cell),
        closeTo(2 / 3, 1e-9),
      );
    });

    test('60秒スピーチ実施済みは1.0（PREP未完了でもキーワードがあれば適用）', () {
      final set = _systemSet(TopicCategory.daily);
      final cell = emptyCell().copyWith(keyword: 'キーワード', speech60Done: true);
      expect(ThinkingMatrixExpansionService.cellWeight(set, cell), 1.0);
    });

    test('キーワードが空ならspeech60Doneが壊れてtrueでも0（isCellSpeech60Doneの定義どおり）', () {
      final set = _systemSet(TopicCategory.daily);
      final cell = emptyCell().copyWith(speech60Done: true);
      expect(ThinkingMatrixExpansionService.cellWeight(set, cell), 0.0);
    });

    test('空白のみのキーワードはtrim後空扱いで0（未入力と同じ）', () {
      final set = _systemSet(TopicCategory.daily);
      final cell = emptyCell().copyWith(keyword: '   ');
      expect(ThinkingMatrixExpansionService.cellWeight(set, cell), 0.0);
    });
  });

  group('ThinkingMatrixExpansionService.gradeForTotalPercent', () {
    test('0%はE', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(0),
        DashboardOverallGrade.e,
      );
    });

    test('0%より大きく25%未満はD', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(0.1),
        DashboardOverallGrade.d,
      );
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(24.9),
        DashboardOverallGrade.d,
      );
    });

    test('ちょうど25%はC', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(25),
        DashboardOverallGrade.c,
      );
    });

    test('ちょうど50%はB', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(50),
        DashboardOverallGrade.b,
      );
    });

    test('ちょうど75%はA', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(75),
        DashboardOverallGrade.a,
      );
    });

    test('49.9%はC、74.9%はB（境界未満は1段階下）', () {
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(49.9),
        DashboardOverallGrade.c,
      );
      expect(
        ThinkingMatrixExpansionService.gradeForTotalPercent(74.9),
        DashboardOverallGrade.b,
      );
    });
  });

  group('ThinkingMatrixExpansionService.build', () {
    test('システムセットが1つも無ければ各0.0%・トータル0.0%・グレードE', () {
      final summary = ThinkingMatrixExpansionService.build(const []);

      expect(summary.dailyPercent, 0.0);
      expect(summary.businessPercent, 0.0);
      expect(summary.situationalPercent, 0.0);
      expect(summary.totalPercent, 0.0);
      expect(summary.expansionGrade, DashboardOverallGrade.e);
      expect(summary.cellCount, 65);
      expect(summary.dailyDisplay, '0.0%');
      expect(summary.totalDisplay, '0.0%');
    });

    test('システムセットは揃っているが全マス空でも同じく全0.0%・グレードE', () {
      final summary = ThinkingMatrixExpansionService.build([
        _systemSet(TopicCategory.daily),
        _systemSet(TopicCategory.business),
        _systemSet(TopicCategory.situational),
      ]);

      expect(summary.dailyPercent, 0.0);
      expect(summary.businessPercent, 0.0);
      expect(summary.situationalPercent, 0.0);
      expect(summary.totalPercent, 0.0);
      expect(summary.expansionGrade, DashboardOverallGrade.e);
    });

    test('日常の1マスだけキーワード入力→日常≈1.3%、トータル≈0.5%、グレードD', () {
      final summary = ThinkingMatrixExpansionService.build([
        _systemSet(TopicCategory.daily, keywordOnlyCount: 1),
      ]);

      expect(summary.dailyPercent, closeTo((1 / 3) / 25 * 100, 1e-9));
      expect(summary.dailyDisplay, '1.3%');
      expect(summary.totalPercent, closeTo((1 / 3) / 65 * 100, 1e-9));
      expect(summary.totalDisplay, '0.5%');
      expect(summary.businessPercent, 0.0);
      expect(summary.situationalPercent, 0.0);
      expect(summary.expansionGrade, DashboardOverallGrade.d);
    });

    test('ビジネスの1マスだけキーワード入力→ビジネス≈1.3%（母数25）、日常・シチュは0%', () {
      final summary = ThinkingMatrixExpansionService.build([
        _systemSet(TopicCategory.business, keywordOnlyCount: 1),
      ]);

      expect(summary.businessPercent, closeTo((1 / 3) / 25 * 100, 1e-9));
      expect(summary.businessDisplay, '1.3%');
      expect(summary.dailyPercent, 0.0);
      expect(summary.situationalPercent, 0.0);
    });

    test('シチュエーションの1マスだけキーワード入力→シチュ≈2.2%（母数15で日常・'
        'ビジネスより分母が小さい分、同じ1/3ウェイトでも%が高く出る）', () {
      final summary = ThinkingMatrixExpansionService.build([
        _systemSet(TopicCategory.situational, keywordOnlyCount: 1),
      ]);

      expect(
        summary.situationalPercent,
        closeTo((1 / 3) / 15 * 100, 1e-9),
      );
      expect(summary.situationalDisplay, '2.2%');
      expect(summary.dailyPercent, 0.0);
      expect(summary.businessPercent, 0.0);
    });

    test('システム外セット（オリジナル・追加の同カテゴリセット）を渡しても無視される', () {
      final extraDaily = ThinkingMatrixSet.create(
        title: '追加の日常セット',
        category: TopicCategory.daily,
        themes: ThinkingMatrixPresets.themesFor(
          TopicCategory.daily,
        ).map(ThinkingTheme.create).toList(),
        columns: ThinkingMatrixPresets.columnsFor(TopicCategory.daily),
      );
      // 全マス60秒スピーチ完了（満点）にしても、systemSetIdsに無いIDなので
      // 集計対象外のはず。
      final fullyDone = extraDaily.copyWith(
        cells: [
          for (final cell in extraDaily.cells)
            cell.copyWith(
              keyword: 'kw',
              conclusion: 'c',
              reason: 'r',
              example: 'e',
              speech60Done: true,
            ),
        ],
      );
      final original = ThinkingMatrixSet.create(
        title: 'オリジナル',
        themes: const [
          'テーマ1',
          'テーマ2',
          'テーマ3',
          'テーマ4',
          'テーマ5',
        ].map(ThinkingTheme.create).toList(),
        columns: ThinkingMatrixPresets.generalColumns,
      );

      final summary = ThinkingMatrixExpansionService.build([
        fullyDone,
        original,
        _systemSet(TopicCategory.daily, keywordOnlyCount: 1),
      ]);

      // fullyDone・originalは無視され、systemの1マスキーワードだけが反映される。
      expect(summary.dailyDisplay, '1.3%');
      expect(summary.expansionGrade, DashboardOverallGrade.d);
    });

    test('3カテゴリすべて満点（トータル100%）はグレードA', () {
      ThinkingMatrixSet fullSet(TopicCategory category) {
        final set = _systemSet(category);
        return set.copyWith(
          cells: [
            for (final cell in set.cells)
              cell.copyWith(
                keyword: 'kw',
                conclusion: 'c',
                reason: 'r',
                example: 'e',
                speech60Done: true,
              ),
          ],
        );
      }

      final summary = ThinkingMatrixExpansionService.build([
        fullSet(TopicCategory.daily),
        fullSet(TopicCategory.business),
        fullSet(TopicCategory.situational),
      ]);

      expect(summary.dailyPercent, 100.0);
      expect(summary.businessPercent, 100.0);
      expect(summary.situationalPercent, 100.0);
      expect(summary.totalPercent, 100.0);
      expect(summary.expansionGrade, DashboardOverallGrade.a);
    });
  });
}
