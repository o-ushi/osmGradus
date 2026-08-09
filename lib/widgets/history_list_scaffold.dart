import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import 'confirm_history_delete_dialog.dart';
import 'history_delete_background.dart';
import 'osm_subpage_scaffold.dart';

/// 左スワイプ削除＋タップで詳細、という osmGenki 流の履歴一覧の共通骨格。
class HistoryListScaffold<T> extends StatefulWidget {
  const HistoryListScaffold({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.languageCode,
    required this.loadAll,
    required this.delete,
    required this.itemId,
    required this.onItemTap,
    required this.buildItem,
  });

  final String title;
  final String emptyMessage;
  final String languageCode;
  final Future<List<T>> Function() loadAll;
  final Future<void> Function(T item) delete;
  final String Function(T item) itemId;
  final void Function(BuildContext context, T item) onItemTap;
  final Widget Function(
    BuildContext context,
    T item,
    AppPalette palette,
    String lang,
  )
  buildItem;

  @override
  State<HistoryListScaffold<T>> createState() =>
      _HistoryListScaffoldState<T>();
}

class _HistoryListScaffoldState<T> extends State<HistoryListScaffold<T>> {
  List<T> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(T target) async {
    await widget.delete(target);
    if (!mounted) return;
    final id = widget.itemId(target);
    setState(
      () => _items = _items.where((item) => widget.itemId(item) != id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text(widget.title.tr(lang)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                widget.emptyMessage.tr(lang),
                style: TextStyle(color: palette.textOnSubpageSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey(widget.itemId(item)),
                  direction: DismissDirection.endToStart,
                  background: const HistoryDeleteBackground(),
                  confirmDismiss: (_) =>
                      confirmHistoryDelete(context, languageCode: lang),
                  onDismissed: (_) => _delete(item),
                  child: GestureDetector(
                    onTap: () => widget.onItemTap(context, item),
                    child: widget.buildItem(context, item, palette, lang),
                  ),
                );
              },
            ),
    );
  }
}
