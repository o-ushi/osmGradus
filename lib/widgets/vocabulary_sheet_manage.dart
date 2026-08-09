part of 'vocabulary_sheet.dart';

/// 登録済み単語の一覧。ドラッグで並び替え、編集・削除・読み上げができる。
class _ManageList extends StatelessWidget {
  const _ManageList({
    required this.lang,
    required this.entries,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
  });

  final String lang;
  final List<VocabularyEntry> entries;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<VocabularyEntry> onEdit;
  final ValueChanged<VocabularyEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            '単語帳_一覧ヒント'.tr(lang),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: entries.length,
            onReorderItem: onReorder,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isBuiltin = JlptVocabBankService.isBuiltinId(entry.id);
              final cardContent = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _ManageBadge(
                          label: entry.level == VocabularyLevel.other
                              ? '単語帳_レベルその他'.tr(lang)
                              : entry.level.storageKey.toUpperCase(),
                        ),
                        if (isBuiltin) _ManageBadge(label: '単語帳_標準'.tr(lang)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.word,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isBuiltin)
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (entry.reading.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '(${entry.reading})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (entry.exampleSentence.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.exampleSentence,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
              return Padding(
                key: ValueKey(entry.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _SwipeActions(
                  enabled: true,
                  onEdit: () => onEdit(entry),
                  onDelete: () => onDelete(entry),
                  editTooltip: '編集'.tr(lang),
                  deleteTooltip: '削除'.tr(lang),
                  child: cardContent,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 一覧行を左スワイプすると、編集・削除ボタンを裏から出す
/// （[SwipeToCloseWrapper]と同じ理由で、専用パッケージではなく
/// `GestureDetector.onHorizontalDrag*`による自前実装にする。
/// [ReorderableListView]の並べ替えは行全体ではなく[ReorderableDragStartListener]
/// で包んだ「＝」ハンドルだけが担うため、この横方向ドラッグと競合しない）。
class _SwipeActions extends StatefulWidget {
  const _SwipeActions({
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.child,
  });

  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editTooltip;
  final String deleteTooltip;
  final Widget child;

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions> {
  static const _actionWidth = 56.0;
  double get _actionsWidth {
    var count = 0;
    if (widget.onEdit != null) count++;
    if (widget.onDelete != null) count++;
    return _actionWidth * count;
  }
  double _dragExtent = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(-_actionsWidth, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldOpen = _dragExtent < -_actionsWidth / 2;
    setState(() => _dragExtent = shouldOpen ? -_actionsWidth : 0);
  }

  void _close() {
    if (_dragExtent == 0) return;
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final palette = AppColors.current;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // カードが動いた分だけ幅を持たせる（常に裏に全幅で置いて
          // カードの不透明度に隠蔽を頼ると、半透明カード越しにボタンが
          // 透けて見えてしまうため、静止時は幅0にして存在ごと消す）。
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: -_dragExtent,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: 0,
                maxWidth: _actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onEdit != null)
                      _SwipeActionButton(
                        icon: Icons.edit_rounded,
                        tooltip: widget.editTooltip,
                        color: palette.accentColor,
                        onTap: () {
                          _close();
                          widget.onEdit!();
                        },
                      ),
                    if (widget.onDelete != null)
                      _SwipeActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: widget.deleteTooltip,
                        color: Colors.red,
                        onTap: () {
                          _close();
                          widget.onDelete!();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onTap: _dragExtent != 0 ? _close : null,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _SwipeActionsState._actionWidth,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Center(child: Icon(icon, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// 一覧行のレベル／標準語彙バッジ（「N1」「Built-in」等）。
class _ManageBadge extends StatelessWidget {
  const _ManageBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

