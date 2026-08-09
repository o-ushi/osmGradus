import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../services/long_article_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/history_timestamp.dart';
import '../../widgets/confirm_history_delete_dialog.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import 'long_article_reader_screen.dart';

/// 保存済み長文の一覧。既定（[selectionMode]がfalse）ではタップで
/// [LongArticleReaderScreen]（Step 3の読解画面を再利用）を開き、単語登録を
/// 続けられる。削除・並び替え・お気に入りは[VocabularySheet]の並び替え
/// （ドラッグハンドル＋`reorderEntries`）と同型のパターンを長文向けに移植した。
///
/// [selectionMode]がtrueのときは、読解画面を自前で開かず、タップした
/// [LongArticle]をそのまま[Navigator.pop]で呼び出し元へ返す（レイヤーⅠの
/// 「一覧から選ぶ」・レイヤーⅤの「長文」で使う。osmCogitoの
/// `CogitoSavedArticleListScreen`と同じ「選んで返すだけ」の役割）。
class LongArticleListScreen extends StatefulWidget {
  const LongArticleListScreen({super.key, this.selectionMode = false});

  /// trueなら、タップした長文を選択結果として呼び出し元へ返す
  /// （このウィジェット自身は読解画面を開かない）。
  final bool selectionMode;

  static Future<LongArticle?> push(
    BuildContext context, {
    bool selectionMode = false,
  }) {
    return Navigator.of(context).push<LongArticle?>(
      MaterialPageRoute<LongArticle?>(
        builder: (_) => LongArticleListScreen(selectionMode: selectionMode),
      ),
    );
  }

  @override
  State<LongArticleListScreen> createState() => _LongArticleListScreenState();
}

class _LongArticleListScreenState extends State<LongArticleListScreen> {
  final _service = LongArticleService();
  bool _loading = true;
  List<LongArticle> _articles = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final articles = await _service.loadArticles();
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final updated = await _service.toggleFavorite(id);
    if (!mounted) return;
    setState(() => _articles = updated);
  }

  Future<void> _delete(String id) async {
    final confirmed = await confirmHistoryDelete(
      context,
      languageCode: appSettings.language,
    );
    if (!confirmed) return;
    final updated = await _service.deleteArticle(id);
    if (!mounted) return;
    setState(() => _articles = updated);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final reordered = List<LongArticle>.from(_articles);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() => _articles = reordered);
    HapticFeedback.selectionClick();
    final updated = await _service.reorderArticles([
      for (final article in reordered) article.id,
    ]);
    if (!mounted) return;
    setState(() => _articles = updated);
  }

  Future<void> _openArticle(LongArticle article) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SwipeToCloseWrapper(
          child: LongArticleReaderScreen(
            body: article.body,
            onFinish: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('長文一覧'.tr(lang)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '長文読解_一覧が空です'.tr(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: palette.textOnSubpageSecondary,
                  ),
                ),
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _articles.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return _LongArticleListTile(
                  key: ValueKey(article.id),
                  index: index,
                  article: article,
                  lang: lang,
                  onTap: widget.selectionMode
                      ? () => Navigator.of(context).pop(article)
                      : () => _openArticle(article),
                  onToggleFavorite: () => _toggleFavorite(article.id),
                  onDelete: () => _delete(article.id),
                );
              },
            ),
    );
  }
}

class _LongArticleListTile extends StatelessWidget {
  const _LongArticleListTile({
    super.key,
    required this.index,
    required this.article,
    required this.lang,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final int index;
  final LongArticle article;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
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
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onToggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 10),
                      child: Icon(
                        article.isFavorite ? Icons.star : Icons.star_border,
                        size: 22,
                        color: article.isFavorite
                            ? const Color(0xFFFFCC00)
                            : palette.textOnCardSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: palette.textOnCardPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatHistoryTimestamp(
                            article.createdAt,
                            languageCode: lang,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.red,
                    visualDensity: VisualDensity.compact,
                    tooltip: '削除'.tr(lang),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: palette.textOnCardSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
