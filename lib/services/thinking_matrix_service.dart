import '../data/thinking_matrix_presets.dart';
import '../models/thinking_matrix_cell.dart';
import '../models/thinking_matrix_cell_status.dart';
import '../models/thinking_matrix_set.dart';
import '../models/thinking_theme.dart';
import '../models/topic_category.dart';
import 'json_list_store.dart';

/// レイヤーⅡ／Ⅲ「25マス思考」（[ThinkingMatrixSet]）のCRUDと、マス埋めの
/// 状態遷移（empty→filled、レイヤーⅢはさらにPREP・60秒スピーチ）を持つ
/// サービス。
class ThinkingMatrixService {
  static final _store = JsonListStore<ThinkingMatrixSet>(
    key: 'thinkingMatrix.sets',
    fromJson: ThinkingMatrixSet.fromJson,
    toJson: (set) => set.toJson(),
    idOf: (set) => set.id,
  );

  Future<List<ThinkingMatrixSet>> loadAll() => _store.loadAll();

  Future<ThinkingMatrixSet?> loadById(String id) async {
    final all = await loadAll();
    for (final set in all) {
      if (set.id == id) return set;
    }
    return null;
  }

  /// 新規セットの追加・既存セットの更新の両方に使う。保存順＝表示順のため、
  /// 触ったセットを先頭に持ってくる（[VocabularyService]と同じ「新しい順」方針）。
  Future<void> save(ThinkingMatrixSet set) async {
    final all = await loadAll();
    final remaining = all.where((s) => s.id != set.id).toList();
    await _store.saveAll([set, ...remaining]);
  }

  Future<void> delete(String id) => _store.delete(id);

  Future<void> clearAll() => _store.clearAll();

  /// オリジナル用（[ThinkingMatrixSet.category]は`null`）。[themeNames]は
  /// ちょうど5つ、trim後いずれも非空であること。列は汎用5列
  /// （[ThinkingMatrixPresets.generalColumns]）。タイトルの自動採番
  /// （「セット1」等）はl10nが必要なため呼び出し側（UI）に任せ、ここでは
  /// [title]を必須で受け取る。
  Future<ThinkingMatrixSet> createSet({
    required String title,
    required List<String> themeNames,
  }) async {
    if (themeNames.length != 5) {
      throw ArgumentError(
        'ThinkingMatrixService.createSet()のthemeNamesはちょうど5つ',
      );
    }
    final trimmedNames = themeNames.map((n) => n.trim()).toList();
    if (trimmedNames.any((n) => n.isEmpty)) {
      throw ArgumentError(
        'ThinkingMatrixService.createSet()のthemeNamesは空にできない',
      );
    }
    final set = ThinkingMatrixSet.create(
      title: title.trim(),
      themes: trimmedNames.map(ThinkingTheme.create).toList(),
      columns: ThinkingMatrixPresets.generalColumns,
    );
    await save(set);
    return set;
  }

  /// カテゴリ別プリセット用（`daily`/`business`/`situational`のみ。`random`は
  /// 分野を持たない抽選専用カテゴリのため拒否し、呼び出し側は代わりに
  /// [createSet]でオリジナルを作る）。テーマ名・列は
  /// [ThinkingMatrixPresets]から埋める。
  Future<ThinkingMatrixSet> createFromPreset(
    TopicCategory category, {
    required String title,
  }) async {
    if (category == TopicCategory.random) {
      throw ArgumentError(
        'ThinkingMatrixService.createFromPreset()はrandomを取らない',
      );
    }
    final set = ThinkingMatrixSet.create(
      title: title.trim(),
      category: category,
      themes: ThinkingMatrixPresets.themesFor(
        category,
      ).map(ThinkingTheme.create).toList(),
      columns: ThinkingMatrixPresets.columnsFor(category),
    );
    await save(set);
    return set;
  }

  Future<ThinkingMatrixSet> renameSet(String id, String title) async {
    final set = await _require(id);
    final updated = set.copyWith(title: title.trim(), updatedAt: DateTime.now());
    await save(updated);
    return updated;
  }

  /// テーマの[id]は変えない（セルは`themeId`参照のままなので、名前を変えても
  /// 既存のキーワードは消えない）。
  Future<ThinkingMatrixSet> updateThemeName(
    String setId,
    String themeId,
    String name,
  ) async {
    final set = await _require(setId);
    final trimmed = name.trim();
    final updatedThemes = [
      for (final theme in set.themes)
        if (theme.id == themeId) theme.copyWith(name: trimmed) else theme,
    ];
    final updated = set.copyWith(
      themes: updatedThemes,
      updatedAt: DateTime.now(),
    );
    await save(updated);
    return updated;
  }

  /// レイヤーⅡ用。キーワードのみを更新する（PREP・60秒スピーチは扱わない）。
  /// [keyword]をtrimして空なら`empty`に戻し、非空なら`filled`にする
  /// （`spoken`は新規保存で使わない）。全マス埋まった瞬間だけ`completedAt`に
  /// 現在時刻を入れ、既に入っていれば上書きしない（初回コンプリート日時を保持）。
  Future<ThinkingMatrixSet> upsertCellLayer2({
    required String setId,
    required String themeId,
    required String columnId,
    required String keyword,
  }) async {
    final set = await _require(setId);
    final trimmedKeyword = keyword.trim();
    final status = trimmedKeyword.isEmpty
        ? ThinkingMatrixCellStatus.empty
        : ThinkingMatrixCellStatus.filled;
    final now = DateTime.now();
    final updatedCells = [
      for (final cell in set.cells)
        if (cell.themeId == themeId && cell.columnId == columnId)
          cell.copyWith(keyword: trimmedKeyword, status: status, updatedAt: now)
        else
          cell,
    ];
    return _saveWithCompletion(set, updatedCells, now);
  }

  /// レイヤーⅢ用。キーワード＋PREP（結論・理由・例示）＋60秒スピーチ完了を
  /// まとめて更新する。[keyword]が空になったら、そのマスのPREP・
  /// `speech60Done`も一緒にクリアする（キーワード無しでPREP・完了フラグだけ
  /// 残る状態を作らない）。
  Future<ThinkingMatrixSet> upsertCellLayer3({
    required String setId,
    required String themeId,
    required String columnId,
    required String keyword,
    String conclusion = '',
    String reason = '',
    String example = '',
    bool speech60Done = false,
  }) async {
    final set = await _require(setId);
    final trimmedKeyword = keyword.trim();
    final isEmpty = trimmedKeyword.isEmpty;
    final status = isEmpty
        ? ThinkingMatrixCellStatus.empty
        : ThinkingMatrixCellStatus.filled;
    final now = DateTime.now();
    final updatedCells = [
      for (final cell in set.cells)
        if (cell.themeId == themeId && cell.columnId == columnId)
          cell.copyWith(
            keyword: trimmedKeyword,
            status: status,
            conclusion: isEmpty ? '' : conclusion.trim(),
            reason: isEmpty ? '' : reason.trim(),
            example: isEmpty ? '' : example.trim(),
            speech60Done: isEmpty ? false : speech60Done,
            updatedAt: now,
          )
        else
          cell,
    ];
    return _saveWithCompletion(set, updatedCells, now);
  }

  Future<ThinkingMatrixSet> _saveWithCompletion(
    ThinkingMatrixSet set,
    List<ThinkingMatrixCell> updatedCells,
    DateTime now,
  ) async {
    final justCompleted =
        set.completedAt == null &&
        updatedCells.every((c) => c.status != ThinkingMatrixCellStatus.empty);
    final updated = set.copyWith(
      cells: updatedCells,
      updatedAt: now,
      completedAt: justCompleted ? now : set.completedAt,
    );
    await save(updated);
    return updated;
  }

  Future<ThinkingMatrixSet> _require(String id) async {
    final set = await loadById(id);
    if (set == null) {
      throw StateError('ThinkingMatrixSet not found: $id');
    }
    return set;
  }
}
