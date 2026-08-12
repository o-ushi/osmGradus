import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/thinking_matrix_cell.dart';
import '../../models/thinking_matrix_cell_status.dart';
import '../../models/thinking_matrix_column.dart';
import '../../models/thinking_matrix_layer.dart';
import '../../models/thinking_matrix_set.dart';
import '../../models/thinking_theme.dart';
import '../../models/topic_category.dart';
import '../../services/thinking_matrix_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_history_delete_dialog.dart';
import '../../widgets/history_delete_background.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/text_edit_sheet.dart';
import '../../widgets/thinking_matrix_cell_sheet.dart';
import '../topics/category_select_sheet.dart';

enum _ThinkingMatrixPhase { list, edit, board }

/// レイヤーⅡ・Ⅲ共通の「25マスで考える」モードのルート（Step 2〜3。Step 3で
/// レイヤーⅢの深掘りと共有化）。Navigatorを使わずlist（セット一覧）→
/// edit（オリジナルのテーマ5つ登録）→board（盤面）の3フェーズを単一の親が
/// 切り替える（[Layer1LongReadingScreen]と同じ設計）。MainShellの常設ヘッダー
/// （Ⅰ〜Ⅴ）の内側にとどまり、[AppHeader]を新たに積まない。
///
/// [layer]でⅡ（キーワードのみ・トロフィー上限1）／Ⅲ（PREP入力も可・
/// トロフィー上限2、60秒スピーチはStep 4）を切り替える。セット一覧・盤面の
/// データは[ThinkingMatrixService]を通じて完全に共有し、Ⅱで作ったセットが
/// そのままⅢでも（逆も）開ける。
///
/// 新規作成は必ず[_ThinkingMatrixCategorySelectSheet]（日常/ビジネス/
/// シチュエーション/オリジナルの4択）を経由する（Step 3）。プリセット3つは
/// 選んだ瞬間に[ThinkingMatrixService.createFromPreset]で盤面まで進み、
/// オリジナルだけ[_ThinkingMatrixPhase.edit]（テーマ5つ入力）に進む。
class ThinkingMatrixScreen extends StatefulWidget {
  const ThinkingMatrixScreen({super.key, required this.layer});

  final ThinkingMatrixLayer layer;

  @override
  State<ThinkingMatrixScreen> createState() => ThinkingMatrixScreenState();
}

class ThinkingMatrixScreenState extends State<ThinkingMatrixScreen> {
  final _service = ThinkingMatrixService();

  bool _loading = true;
  _ThinkingMatrixPhase _phase = _ThinkingMatrixPhase.list;
  List<ThinkingMatrixSet> _sets = const [];
  String? _boardSetId;

  @override
  void initState() {
    super.initState();
    // appSettingsの変更を直接購読し、設定画面から戻っただけでも再描画する
    // （[Layer2RandomScreenState]と同じ理由）。
    appSettings.addListener(_onSettingsChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _load() async {
    final sets = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
      _phase = _ThinkingMatrixPhase.list;
    });
    // セットが0件でモードに入ったときだけ、カテゴリ選択を直接出す
    // （いきなりテーマ5つ入力にはしない）。
    if (sets.isEmpty) {
      await _startCreate();
    }
  }

  /// カテゴリ選択（日常/ビジネス/シチュエーション/オリジナル）を開く。
  /// キャンセル（シートを閉じる）は4択へは出さず、一覧（空ならその空状態）へ
  /// 戻すだけで何もしない。プリセット3つは選んだ瞬間に盤面まで進み、
  /// オリジナルだけテーマ5つ入力（edit）へ進む。
  Future<void> _startCreate() async {
    final choice = await _ThinkingMatrixCategorySelectSheet.show(context);
    if (choice == null || !mounted) return;
    final category = choice.category;
    if (category == null) {
      setState(() => _phase = _ThinkingMatrixPhase.edit);
      return;
    }
    final lang = appSettings.language;
    final title = '25マス_セット名_連番'.trFmt(lang, ['${_sets.length + 1}']);
    final set = await _service.createFromPreset(category, title: title);
    await _onCreated(set);
  }

  /// 登録のキャンセル相当。4択へは出さず、一覧（空ならその空状態）へ戻す。
  void _cancelEdit() => setState(() => _phase = _ThinkingMatrixPhase.list);

  Future<void> _onCreated(ThinkingMatrixSet set) async {
    final sets = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _boardSetId = set.id;
      _phase = _ThinkingMatrixPhase.board;
    });
  }

  void _openSet(String id) => setState(() {
    _boardSetId = id;
    _phase = _ThinkingMatrixPhase.board;
  });

  Future<void> _backToList() async {
    final sets = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _phase = _ThinkingMatrixPhase.list;
    });
  }

  /// 左スワイプ削除の確認ダイアログ（[Dismissible.confirmDismiss]用。実際の
  /// 削除は行わず、続けるかどうかだけを返す）。
  Future<bool> _confirmDelete() =>
      confirmHistoryDelete(context, languageCode: appSettings.language);

  /// [_confirmDelete]で確認済みの削除を実行する（[Dismissible.onDismissed]用）。
  Future<void> _delete(String id) async {
    await _service.delete(id);
    final sets = await _service.loadAll();
    if (!mounted) return;
    setState(() => _sets = sets);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppColors.current.scene,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return switch (_phase) {
      _ThinkingMatrixPhase.list => _ThinkingMatrixListView(
        sets: _sets,
        onCreate: _startCreate,
        onOpen: _openSet,
        onConfirmDelete: _confirmDelete,
        onDelete: _delete,
      ),
      _ThinkingMatrixPhase.edit => _ThinkingMatrixEditView(
        setCount: _sets.length,
        onCancel: _cancelEdit,
        onCreated: _onCreated,
      ),
      _ThinkingMatrixPhase.board => _ThinkingMatrixBoardView(
        setId: _boardSetId!,
        layer: widget.layer,
        onBack: _backToList,
      ),
    };
  }
}

/// [_ThinkingMatrixCategorySelectSheet]の選択結果。[category]が非nullなら
/// プリセット3つのいずれか、nullなら「オリジナル」を表す（シートのキャンセルは
/// `show()`自体がnullをpopするため、ここでは区別する必要が無い）。
class _ThinkingMatrixCategoryChoice {
  const _ThinkingMatrixCategoryChoice.preset(this.category);

  const _ThinkingMatrixCategoryChoice.original() : category = null;

  final TopicCategory? category;
}

/// 25マス新規作成のカテゴリ選択（日常/ビジネス/シチュエーション/オリジナル）。
/// 問題文用の[CategorySelectSheet]と行の見た目（[CategorySelectRow]）を
/// 共有するが、`random`を出さず4行目に「オリジナル」を足すため戻り値の型が
/// 異なる別シートにしている。
class _ThinkingMatrixCategorySelectSheet extends StatelessWidget {
  const _ThinkingMatrixCategorySelectSheet();

  static const _presetCategories = [
    TopicCategory.daily,
    TopicCategory.business,
    TopicCategory.situational,
  ];

  static Future<_ThinkingMatrixCategoryChoice?> show(BuildContext context) {
    final palette = AppColors.current;
    return showModalBottomSheet<_ThinkingMatrixCategoryChoice>(
      context: context,
      backgroundColor: palette.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ThinkingMatrixCategorySelectSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'カテゴリ'.tr(lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in _presetCategories)
              CategorySelectRow(
                label: category.labelKey().tr(lang),
                selected: false,
                onTap: () => Navigator.of(context).pop(
                  _ThinkingMatrixCategoryChoice.preset(category),
                ),
              ),
            CategorySelectRow(
              label: 'オリジナル'.tr(lang),
              selected: false,
              onTap: () => Navigator.of(
                context,
              ).pop(const _ThinkingMatrixCategoryChoice.original()),
            ),
          ],
        ),
      ),
    );
  }
}

/// セット一覧。タップでboardへ、＋でカテゴリ選択へ、削除は左スワイプ
/// （[confirmHistoryDelete]の確認を経由）。「＋」長押しでこの一覧自体の
/// 使い方シートを開く（他のレイヤー一覧と同じ操作方法）。
class _ThinkingMatrixListView extends StatelessWidget {
  const _ThinkingMatrixListView({
    required this.sets,
    required this.onCreate,
    required this.onOpen,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  final List<ThinkingMatrixSet> sets;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;
  final Future<bool> Function() onConfirmDelete;
  final ValueChanged<String> onDelete;

  void _showUsageHelp(BuildContext context) {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(
          text: '25マス_一覧_使い方_追加'.tr(lang),
          icon: Icons.add_rounded,
        ),
        LayerHelpLine(text: '25マス_一覧_使い方_詳細'.tr(lang)),
        LayerHelpLine(text: '25マス_一覧_使い方_削除'.tr(lang)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '25マス思考'.tr(lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: palette.textOnScenePrimary,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '25マスボードを作成'.tr(lang),
                    triggerMode: TooltipTriggerMode.manual,
                    child: InkWell(
                      onTap: onCreate,
                      onLongPress: () => _showUsageHelp(context),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.add_rounded,
                          color: palette.textOnScenePrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sets.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          '25マス_一覧が空です'.tr(lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textOnSceneSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: sets.length,
                      itemBuilder: (context, index) {
                        final set = sets[index];
                        return _ThinkingMatrixSetTile(
                          set: set,
                          lang: lang,
                          onTap: () => onOpen(set.id),
                          onConfirmDelete: onConfirmDelete,
                          onDelete: () => onDelete(set.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingMatrixSetTile extends StatelessWidget {
  const _ThinkingMatrixSetTile({
    required this.set,
    required this.lang,
    required this.onTap,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  final ThinkingMatrixSet set;
  final String lang;
  final VoidCallback onTap;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final percent = (set.completionRatio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(set.id),
        direction: DismissDirection.endToStart,
        background: const HistoryDeleteBackground(),
        confirmDismiss: (_) => onConfirmDelete(),
        onDismissed: (_) => onDelete(),
        child: Container(
          // Dismissibleは内部でStack（StackFit.loose）を使うため、幅の制約が
          // 緩められて子（このContainer）が横幅いっぱいまで広がらず、カードが
          // テキスト幅に縮んでしまう。明示的にwidth: double.infinityを指定して
          // 一覧の他の行と幅を揃える。
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.textOnCardPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (set.category?.labelKey() ?? 'オリジナル').tr(lang),
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textOnCardSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '25マス_達成率'.trFmt(lang, [
                        '$percent',
                        '${set.filledCount}',
                        '${set.totalCells}',
                      ]),
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textOnCardSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// オリジナル用、テーマ5つの登録画面（Step 3。カテゴリ選択で「オリジナル」を
/// 選んだときだけ進む）。タイトルは空なら「セットN」を自動採番する。
class _ThinkingMatrixEditView extends StatefulWidget {
  const _ThinkingMatrixEditView({
    required this.setCount,
    required this.onCancel,
    required this.onCreated,
  });

  final int setCount;
  final VoidCallback onCancel;
  final ValueChanged<ThinkingMatrixSet> onCreated;

  @override
  State<_ThinkingMatrixEditView> createState() =>
      _ThinkingMatrixEditViewState();
}

class _ThinkingMatrixEditViewState extends State<_ThinkingMatrixEditView> {
  final _service = ThinkingMatrixService();
  final _titleController = TextEditingController();
  final _themeControllers = List.generate(5, (_) => TextEditingController());
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _themeControllers) {
      controller.addListener(_onFieldsChanged);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _themeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFieldsChanged() => setState(() {});

  bool get _canCreate =>
      !_creating &&
      _themeControllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _creating = true);
    final lang = appSettings.language;
    final trimmedTitle = _titleController.text.trim();
    final title = trimmedTitle.isNotEmpty
        ? trimmedTitle
        : '25マス_セット名_連番'.trFmt(lang, ['${widget.setCount + 1}']);
    final set = await _service.createSet(
      title: title,
      themeNames: [for (final c in _themeControllers) c.text],
    );
    if (!mounted) return;
    widget.onCreated(set);
  }

  Widget _buildField(TextEditingController controller, String hintText) {
    final palette = AppColors.current;
    return TextField(
      controller: controller,
      style: TextStyle(color: palette.textOnScenePrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: palette.textOnSceneSecondary),
        filled: true,
        fillColor: palette.textOnScenePrimary.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: palette.textOnScenePrimary,
                    tooltip: '戻る'.tr(lang),
                  ),
                  Expanded(
                    child: Text(
                      '25マス思考'.tr(lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: palette.textOnScenePrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        _titleController,
                        '25マス_タイトル入力例'.tr(lang),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'テーマ'.tr(lang),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final controller in _themeControllers) ...[
                        _buildField(controller, '25マス_ネタ入力例'.tr(lang)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canCreate ? _create : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accentColor,
                    foregroundColor: palette.onAccent,
                    disabledBackgroundColor: palette.cardBorder,
                  ),
                  child: _creating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.onAccent,
                          ),
                        )
                      : Text('25マスボードを作成'.tr(lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// マス目のテーマID・列IDで一意なキー（ビンゴのハイライト対象を管理する用途）。
String _cellKey(String themeId, String columnId) => '$themeId:$columnId';

/// ボード（5×5、シチュエーションは5×3）。セルタップで
/// [ThinkingMatrixCellSheet]を開きキーワードを保存する。テーマ編集アイコンで
/// テーマ5つの名前だけを編集できる。進捗プログレスバー・列バッジ・
/// ビンゴ演出・コンプリートダイアログも持つ。
class _ThinkingMatrixBoardView extends StatefulWidget {
  const _ThinkingMatrixBoardView({
    required this.setId,
    required this.layer,
    required this.onBack,
  });

  final String setId;
  final ThinkingMatrixLayer layer;
  final VoidCallback onBack;

  @override
  State<_ThinkingMatrixBoardView> createState() =>
      _ThinkingMatrixBoardViewState();
}

class _ThinkingMatrixBoardViewState extends State<_ThinkingMatrixBoardView> {
  final _service = ThinkingMatrixService();
  ThinkingMatrixSet? _set;
  bool _loading = true;

  /// 「今回の保存で初めて揃った」行・列に属する全マスのキー。パルス中だけ
  /// 中身がある。[_bingoPulseOn]と組み合わせてAnimatedContainerで数回点滅させる。
  Set<String> _bingoKeys = const {};
  bool _bingoPulseOn = false;
  Timer? _bingoTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _bingoTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final set = await _service.loadById(widget.setId);
    if (!mounted) return;
    setState(() {
      _set = set;
      _loading = false;
    });
  }

  Future<void> _editThemes() async {
    final set = _set;
    if (set == null) return;
    final palette = AppColors.current;
    final updated = await showModalBottomSheet<ThinkingMatrixSet>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThinkingMatrixThemeEditSheet(service: _service, set: set),
    );
    if (updated == null || !mounted) return;
    setState(() => _set = updated);
  }

  /// ボード見出しタップでセットタイトルをインライン編集する（Step 5）。
  Future<void> _renameTitle() async {
    final set = _set;
    if (set == null) return;
    final lang = appSettings.language;
    final newTitle = await TextEditSheet.show(
      context,
      title: '25マス_タイトル編集'.tr(lang),
      initialValue: set.title,
    );
    if (newTitle == null || !mounted) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == set.title) return;
    final updated = await _service.renameSet(set.id, trimmed);
    if (!mounted) return;
    setState(() => _set = updated);
  }

  Future<void> _openCell(ThinkingTheme theme, ThinkingMatrixColumn column) async {
    final set = _set;
    if (set == null) return;
    final themeIndex = set.themes.indexWhere((t) => t.id == theme.id);
    final wasRowFilled = set.isRowFilled(themeIndex);
    final wasColumnFilled = set.isColumnFilled(column.id);

    final updated = await ThinkingMatrixCellSheet.show(
      context,
      service: _service,
      set: set,
      theme: theme,
      column: column,
      cell: set.cellFor(theme.id, column.id),
      layer: widget.layer,
    );
    if (updated == null || !mounted) return;

    // 「今回の保存で初めて揃った」行・列だけを対象にする（開いただけ・既に
    // 揃っていた場合はビンゴを出さない）。
    final newlyCompletedKeys = <String>{};
    if (!wasRowFilled && updated.isRowFilled(themeIndex)) {
      for (final c in set.columns) {
        newlyCompletedKeys.add(_cellKey(theme.id, c.id));
      }
    }
    if (!wasColumnFilled && updated.isColumnFilled(column.id)) {
      for (final t in updated.themes) {
        newlyCompletedKeys.add(_cellKey(t.id, column.id));
      }
    }
    // completedAtは初回コンプリートの瞬間だけ入る
    // （_saveWithCompletion、upsertCellLayer2・upsertCellLayer3共通の契約）。
    // 再コンプリートでは既に値があるため、ここは常にfalseになる。
    final justCompletedBoard =
        set.completedAt == null && updated.completedAt != null;

    setState(() => _set = updated);

    if (newlyCompletedKeys.isNotEmpty) {
      _triggerBingo(newlyCompletedKeys);
    }
    if (justCompletedBoard) {
      await _showCompleteDialog();
    }
  }

  void _triggerBingo(Set<String> keys) {
    HapticFeedback.mediumImpact();
    _bingoTimer?.cancel();
    setState(() {
      _bingoKeys = keys;
      _bingoPulseOn = true;
    });
    var pulses = 0;
    _bingoTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      pulses++;
      // 6回のトグル（オン→オフ×3）で止める。無限アニメーションにはしない。
      if (pulses >= 6) {
        timer.cancel();
        setState(() {
          _bingoKeys = const {};
          _bingoPulseOn = false;
        });
        return;
      }
      setState(() => _bingoPulseOn = !_bingoPulseOn);
    });
  }

  Future<void> _showCompleteDialog() async {
    if (!mounted) return;
    final lang = appSettings.language;
    final totalCells = _set?.totalCells ?? 25;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('25マスコンプリート'.tr(lang)),
        content: Text(
          '25マス_コンプリート_本文'.trFmt(lang, ['$totalCells']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('OK'.tr(lang)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final set = _set;
    if (_loading || set == null) {
      return Container(
        color: palette.scene,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final percent = (set.completionRatio * 100).round();
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: palette.textOnScenePrimary,
                    tooltip: '戻る'.tr(lang),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _renameTitle,
                      child: Text(
                        set.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: palette.textOnScenePrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _editThemes,
                    icon: const Icon(Icons.edit_rounded),
                    color: palette.textOnScenePrimary,
                    tooltip: 'テーマ'.tr(lang),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: set.completionRatio,
                  minHeight: 6,
                  backgroundColor: palette.textOnScenePrimary.withValues(
                    alpha: 0.15,
                  ),
                  color: kThinkingMatrixGoldColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '25マス_達成率'.trFmt(lang, [
                  '$percent',
                  '${set.filledCount}',
                  '${set.totalCells}',
                ]),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textOnSceneSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _ThinkingMatrixGrid(
                  set: set,
                  layer: widget.layer,
                  onCellTap: _openCell,
                  bingoKeys: _bingoPulseOn ? _bingoKeys : const {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [layer]における表示上限に切り詰めたトロフィー段階を返す（[ThinkingMatrixSet]
/// の生の[ThinkingMatrixSet.trophyTierForRow]・[ThinkingMatrixSet.trophyTierForColumn]
/// は最大4だが、Ⅱの盤面はキーワードのみを扱うため揃っていれば常に1つに
/// 切り詰める。Ⅲの盤面はそのまま最大4を表示する）。
int _displayTrophyTier(ThinkingMatrixLayer layer, int rawTier) {
  final cap = switch (layer) {
    ThinkingMatrixLayer.layer2 => 1,
    ThinkingMatrixLayer.layer3 => 4,
  };
  return rawTier > cap ? cap : rawTier;
}

class _ThinkingMatrixGrid extends StatelessWidget {
  const _ThinkingMatrixGrid({
    required this.set,
    required this.layer,
    required this.onCellTap,
    this.bingoKeys = const {},
  });

  final ThinkingMatrixSet set;
  final ThinkingMatrixLayer layer;
  final void Function(ThinkingTheme theme, ThinkingMatrixColumn column)
  onCellTap;

  /// 現在パルス中のマスのキー（[_cellKey]）。空ならどのマスもハイライトしない。
  final Set<String> bingoKeys;

  static const _labelColumnWidth = 60.0;

  /// マスターアイコンのサイズ・確保する正方スロット幅（行・列共通）。
  static const _masterIconSize = 12.0;

  /// 列マスターアイコン行の高さ。揃っている列が0でもこの高さを常に確保し、
  /// 新たに列が揃ってアイコンが出ても見出し・盤面がずれないようにする。
  static const _masterIconRowHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Column(
      children: [
        Row(
          children: [
            // 左上の隅：縦軸＝テーマ、横軸＝視点だと分かる小さな案内。
            // 列の個別見出し（時間・視点・比較…／職場・学校・病院）と文字が
            // 被らないよう、1つのTextにまとめて他では使わない表記にする。
            SizedBox(
              width: _labelColumnWidth,
              child: Text(
                '${'テーマ'.tr(lang)}／${'視点'.tr(lang)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  color: palette.textOnSceneSecondary,
                ),
              ),
            ),
            for (final column in set.columns)
              Expanded(
                child: SizedBox(
                  height: _masterIconRowHeight,
                  child: _ThinkingMatrixMasterBadges(
                    tier: _displayTrophyTier(
                      layer,
                      set.trophyTierForColumn(column.id),
                    ),
                    iconSize: _masterIconSize,
                    tooltip: '25マス_ネタコンプリート'.trFmt(lang, [
                      column.labelKey.tr(lang),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: _labelColumnWidth),
            for (final column in set.columns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      column.labelKey.tr(lang),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textOnScenePrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < set.themes.length; i++)
                Expanded(
                  child: Row(
                    // ラベル欄は内容量ぶんだけの高さに収めて上詰めにする
                    // （5マス側は_ThinkingMatrixCellViewのalignment指定により
                    // 行の高さいっぱいまで広がるため、ここを変えても縮まない）。
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _labelColumnWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 2,
                            right: 2,
                            top: 1,
                          ),
                          // 列見出し（視点）と同じ「アイコンが上・ラベルが下」の
                          // 縦積みにする。列側のアイコン行とは完全に独立した
                          // 別要素（幅の奪い合いをしない、混ざらない）。
                          // 両方をFlexibleにして、極端に行の高さが低いとき
                          // （キーボード表示中の背面など）でもRenderFlexの
                          // オーバーフローにならず、収まる分だけ縮んで描画する。
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: SizedBox(
                                  height: _masterIconRowHeight,
                                  child: _ThinkingMatrixMasterBadges(
                                    tier: _displayTrophyTier(
                                      layer,
                                      set.trophyTierForRow(i),
                                    ),
                                    iconSize: _masterIconSize,
                                    tooltip: '25マス_ネタコンプリート'.trFmt(lang, [
                                      themeDisplayName(
                                        set,
                                        set.themes[i],
                                        lang,
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  themeDisplayName(
                                    set,
                                    set.themes[i],
                                    lang,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textOnScenePrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final column in set.columns)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: Builder(
                              builder: (context) {
                                final cell = set.cellFor(
                                  set.themes[i].id,
                                  column.id,
                                );
                                // Ⅱは常にキーワードのみの見た目に留める
                                // （データにⅢ由来のPREP・60秒スピーチが
                                // 残っていても、Ⅱの盤面では出さない）。
                                final isLayer3 =
                                    layer == ThinkingMatrixLayer.layer3;
                                return _ThinkingMatrixCellView(
                                  cell: cell,
                                  onTap: () =>
                                      onCellTap(set.themes[i], column),
                                  highlighted: bingoKeys.contains(
                                    _cellKey(set.themes[i].id, column.id),
                                  ),
                                  prepComplete:
                                      isLayer3 &&
                                      set.isCellPrepComplete(cell),
                                  speechDone:
                                      isLayer3 &&
                                      set.isCellSpeech60Done(cell),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 行・列が揃ったときのトロフィー表示。[tier]（[ThinkingMatrixSet.trophyTierForRow]・
/// [ThinkingMatrixSet.trophyTierForColumn]を[_displayTrophyTier]で盤面の
/// レイヤーごとの上限に切り詰めた値）の数だけトロフィーを出す。0なら何も
/// 出さない。
class _ThinkingMatrixMasterBadges extends StatelessWidget {
  const _ThinkingMatrixMasterBadges({
    required this.tier,
    required this.iconSize,
    required this.tooltip,
  });

  final int tier;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (tier <= 0) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < tier; i++)
            Icon(
              Icons.workspace_premium_rounded,
              size: iconSize,
              color: kThinkingMatrixGoldColor,
            ),
        ],
      ),
    );
  }
}

/// マスの背景色・枠線を5段階で分ける。
/// 1. 未入力：透明
/// 2. キーワードのみ：[AppPalette.cardFill]
/// 3. PREP（結論・理由・例示）まで完了：[kThinkingMatrixPrepCompleteColor]
/// 4. キーワード＋60秒スピーチ完了（PREP未完了）：[kThinkingMatrixSpeechOnlyColor]
/// 5. PREP＋60秒スピーチ完了：背景は段階4と同じ[kThinkingMatrixSpeechOnlyColor]
///    のまま、枠線だけ[kThinkingMatrixCompleteBorderColor]の太枠にして最終段階を示す。
///
/// レイヤーⅡの盤面では[prepComplete]・[speechDone]を常にfalseで渡すため、
/// 段階2止まり（旧`spoken`「1分話した」自己申告のマスもfilledと同じ見た目、
/// データそのものの整理は別Step）。タップで[ThinkingMatrixCellSheet]を開く。
/// [highlighted]がtrueの間（ビンゴ演出中）は枠を白く光らせる。
class _ThinkingMatrixCellView extends StatelessWidget {
  const _ThinkingMatrixCellView({
    required this.cell,
    required this.onTap,
    this.highlighted = false,
    this.prepComplete = false,
    this.speechDone = false,
  });

  final ThinkingMatrixCell cell;
  final VoidCallback onTap;
  final bool highlighted;

  /// キーワード・結論・理由・例示がすべて非空か（レイヤーⅡの盤面では常にfalse）。
  final bool prepComplete;

  /// 60秒スピーチを完了したか（レイヤーⅡの盤面では常にfalse）。
  final bool speechDone;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final status = cell.status == ThinkingMatrixCellStatus.spoken
        ? ThinkingMatrixCellStatus.filled
        : cell.status;
    final isFilled = status != ThinkingMatrixCellStatus.empty;
    final Color background;
    final Color border;
    final double borderWidth;
    final Color foreground;
    if (!isFilled) {
      // 段階1：未入力は透明（シーンの青地がそのまま透ける）。
      background = Colors.transparent;
      border = palette.textOnScenePrimary.withValues(alpha: 0.2);
      borderWidth = 1;
      foreground = palette.textOnScenePrimary.withValues(alpha: 0.4);
    } else if (prepComplete && speechDone) {
      // 段階5：PREP＋60秒スピーチ完了（最終段階）。背景は段階4と同じにし、
      // ピンクの太枠だけで最終段階だと分かるようにする。
      background = kThinkingMatrixSpeechOnlyColor;
      border = kThinkingMatrixCompleteBorderColor;
      borderWidth = 3.5;
      foreground = palette.textOnCardPrimary;
    } else if (speechDone) {
      // 段階4：キーワード＋60秒スピーチ完了（PREPは未完了）。
      background = kThinkingMatrixSpeechOnlyColor;
      border = palette.cardBorder;
      borderWidth = 1;
      foreground = palette.textOnCardPrimary;
    } else if (prepComplete) {
      // 段階3：PREP（結論・理由・例示）まで完了。
      background = kThinkingMatrixPrepCompleteColor;
      border = palette.cardBorder;
      borderWidth = 1;
      foreground = palette.textOnCardPrimary;
    } else {
      // 段階2：キーワードのみ。
      background = palette.cardFill;
      border = palette.cardBorder;
      borderWidth = 1;
      foreground = palette.textOnCardPrimary;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlighted ? Colors.white : border,
              width: highlighted ? 2.5 : borderWidth,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(1),
          child: isFilled
              ? Text(
                  cell.keyword,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: foreground),
                )
              : Icon(Icons.add_rounded, size: 16, color: foreground),
        ),
      ),
    );
  }
}

/// ボードのテーマ編集アイコンから開く、テーマ5つの名前だけを編集するシート。
/// [TextEditSheet]と同型のモーダルボトムシート。IDは変えないため、キーワード
/// （Step 3以降）は保持される。
class _ThinkingMatrixThemeEditSheet extends StatefulWidget {
  const _ThinkingMatrixThemeEditSheet({
    required this.service,
    required this.set,
  });

  final ThinkingMatrixService service;
  final ThinkingMatrixSet set;

  @override
  State<_ThinkingMatrixThemeEditSheet> createState() =>
      _ThinkingMatrixThemeEditSheetState();
}

class _ThinkingMatrixThemeEditSheetState
    extends State<_ThinkingMatrixThemeEditSheet> {
  late final _controllers = [
    for (final theme in widget.set.themes)
      TextEditingController(text: theme.name),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    var current = widget.set;
    for (var i = 0; i < current.themes.length; i++) {
      final trimmed = _controllers[i].text.trim();
      if (trimmed == current.themes[i].name) continue;
      current = await widget.service.updateThemeName(
        current.id,
        current.themes[i].id,
        trimmed,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(current);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        // ネタ5欄＋見出し＋ボタンはキーボード表示時に画面高を超えることがある
        // ため、SingleChildScrollViewで包んでオーバーフローさせず縦スクロール
        // に逃がす（TextEditSheet等の1〜数欄のシートには無い問題）。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'テーマ'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final controller in _controllers) ...[
                TextField(
                  controller: controller,
                  style: TextStyle(
                    color: palette.textOnCardPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: palette.subpageBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('キャンセル'.tr(lang)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text('保存'.tr(lang)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
