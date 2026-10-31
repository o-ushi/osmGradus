import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../models/saved_vocabulary_check.dart';
import '../../services/long_article_service.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../utils/history_timestamp.dart';
import '../../widgets/confirm_history_delete_dialog.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import 'long_article_flow_screen.dart';
import 'vocabulary_check_detail_screen.dart';

/// 保存済み長文の一覧。既定（[selectionMode]がfalse）ではタップで
/// [Layer1LongReadingScreen]（`initialArticle`付き）を開き、読解→
/// （1秒チェック）→（語彙テスト）の一連を通しで辿れる（単語登録も続けられる。
/// 保存済みなので終了時に複製・再保存はしない）。削除・並び替え・お気に入りは
/// [VocabularySheet]の並び替え（ドラッグハンドル＋`reorderEntries`）と同型の
/// パターンを長文向けに移植した。
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

  /// 一覧からの閲覧も、読解→（1秒チェック）→（語彙テスト）の一連に載せる
  /// （[Layer1LongReadingScreen]を`initialArticle`付きで再利用。保存済み
  /// なので終了時に複製・再保存はされない）。
  Future<void> _openArticle(LongArticle article) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SwipeToCloseWrapper(
          child: Layer1LongReadingScreen(
            initialArticle: article,
            onBackToModeSelect: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
    // 語彙テストの採点でcounts/lastVocabularyCheckIdが変わっている可能性が
    // あるため、一覧へ戻ったら読み直す。
    await _load();
  }

  /// 正解率タップ時: [LongArticle.lastVocabularyCheckId]があれば履歴から
  /// 該当[SavedVocabularyCheck]を探し、[VocabularyCheckDetailScreen]を開く。
  /// 未実施（[LongArticle.hasVocabTestResult]がfalse）なら何もしない。
  /// IDはあるが履歴側の記録が見つからない（削除済み等）場合はSnackBarで
  /// 案内する（新規の簡易詳細画面は作らない）。
  Future<void> _onAccuracyTap(LongArticle article) async {
    if (!article.hasVocabTestResult) return;
    final checkId = article.lastVocabularyCheckId;
    SavedVocabularyCheck? check;
    if (checkId != null) {
      final checks = await VocabularyCheckStorage().loadAll();
      for (final candidate in checks) {
        if (candidate.id == checkId) {
          check = candidate;
          break;
        }
      }
    }
    if (!mounted) return;
    if (check == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('長文読解_語彙_結果詳細なし'.tr(appSettings.language)),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VocabularyCheckDetailScreen(check: check!),
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
                  selectionMode: widget.selectionMode,
                  onTap: widget.selectionMode
                      ? () => Navigator.of(context).pop(article)
                      : () => _openArticle(article),
                  onToggleFavorite: () => _toggleFavorite(article.id),
                  onDelete: () => _delete(article.id),
                  onAccuracyTap: () => _onAccuracyTap(article),
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
    required this.selectionMode,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onAccuracyTap,
  });

  final int index;
  final LongArticle article;
  final String lang;

  /// trueのときは行全体のタップが「選んで返す」を担うため、正解率テキストは
  /// 独立してタップ可能にしない（既存の一覧選択UXを壊さない）。
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onAccuracyTap;

  String _accuracyLabel(String lang) {
    final accuracy = article.vocabTestAccuracy;
    final value = accuracy == null ? 'ー' : '${(accuracy * 100).round()}%';
    return '長文読解_正解率'.trFmt(lang, [value]);
  }

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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                formatHistoryTimestamp(
                                  article.createdAt,
                                  languageCode: lang,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textOnCardSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            selectionMode
                                ? Text(
                                    _accuracyLabel(lang),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.textOnCardSecondary,
                                    ),
                                  )
                                : GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onAccuracyTap,
                                    child: Text(
                                      _accuracyLabel(lang),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: article.hasVocabTestResult
                                            ? palette.accentColor
                                            : palette.textOnCardSecondary,
                                      ),
                                    ),
                                  ),
                          ],
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
