import 'package:flutter/material.dart';

import '../../data/curated_shows.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/podcast_show.dart';
import '../../services/itunes_podcast_search_service.dart';
import '../../services/podcast_feed_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/curated_show_card.dart';
import '../../widgets/podcast_show_tile.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// osmPodの「番組追加」画面の移植。上から順に
/// 「RSS URLで追加」→「検索（iTunes Search API）」→「おすすめ」の3セクション。
/// osmPodはこれに加えてAI提案・ローカルファイル取り込みも持つが、
/// この土台段階では外部AI依存を避け、実用性の高い2手段＋おすすめに絞る。
class AddShowScreen extends StatefulWidget {
  const AddShowScreen({
    super.key,
    required this.registeredShowIds,
    required this.onSelect,
    required this.onDelete,
  });

  final Set<String> registeredShowIds;
  final ValueChanged<PodcastShow> onSelect;
  final ValueChanged<PodcastShow> onDelete;

  static Future<void> push(
    BuildContext context, {
    required Set<String> registeredShowIds,
    required ValueChanged<PodcastShow> onSelect,
    required ValueChanged<PodcastShow> onDelete,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => AddShowScreen(
          registeredShowIds: registeredShowIds,
          onSelect: onSelect,
          onDelete: onDelete,
        ),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _AddShowScreenState extends State<AddShowScreen> {
  final _searchService = ITunesPodcastSearchService();
  final _feedService = PodcastFeedService();
  final _urlController = TextEditingController();
  final _searchController = TextEditingController();

  final Set<String> _registeredShowIds = {};

  bool _urlLoading = false;
  String? _urlError;

  List<PodcastShow> _searchResults = [];
  bool _searching = false;
  String? _searchError;

  String? _curatedLoadingId;
  String? _curatedError;

  @override
  void initState() {
    super.initState();
    _registeredShowIds.addAll(widget.registeredShowIds);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(PodcastShow show) async {
    if (!_registeredShowIds.contains(show.id)) {
      widget.onSelect(show);
      setState(() => _registeredShowIds.add(show.id));
      return;
    }

    final lang = appSettings.language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('番組を削除'.tr(lang)),
        content: Text(
          '「%1@」を削除しますか？\nエピソードの再生履歴も削除されます。'.trFmt(lang, [show.title]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'.tr(lang)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '削除'.tr(lang),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onDelete(show);
    if (mounted) setState(() => _registeredShowIds.remove(show.id));
  }

  Future<void> _addByUrl() async {
    final lang = appSettings.language;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() => _urlError = '正しいURL（http/https）を入力してください'.tr(lang));
      return;
    }

    setState(() {
      _urlLoading = true;
      _urlError = null;
    });
    try {
      final show = await _feedService.fetchShowMetadata(url);
      await _handleTap(show);
      _urlController.clear();
    } catch (e) {
      setState(() => _urlError = 'フィードを読み込めませんでした'.tr(lang));
    } finally {
      if (mounted) setState(() => _urlLoading = false);
    }
  }

  Future<void> _searchCurated(CuratedPodcastQuery query) async {
    final lang = appSettings.language;
    setState(() {
      _curatedLoadingId = query.id;
      _curatedError = null;
      _searchError = null;
    });
    try {
      final results = await _searchService.search(query.searchTerm);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() {
          _curatedError = 'おすすめに該当する番組が見つかりませんでした'.tr(lang);
          _curatedLoadingId = null;
        });
        return;
      }
      setState(() => _curatedLoadingId = null);
      await _confirmAndRegister(_pickCuratedShow(results, query.searchTerm));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _curatedError = '検索に失敗しました'.tr(lang);
        _curatedLoadingId = null;
      });
    }
  }

  /// iTunes Search は複数ヒットすることがあるが、おすすめは常に1件の確認ダイアログへ。
  PodcastShow _pickCuratedShow(List<PodcastShow> results, String searchTerm) {
    final needle = _normalizeCuratedMatchKey(searchTerm);
    for (final show in results) {
      if (_normalizeCuratedMatchKey(show.title) == needle) return show;
    }
    for (final show in results) {
      final hay = _normalizeCuratedMatchKey(show.title);
      if (hay.contains(needle) || needle.contains(hay)) return show;
    }
    return results.first;
  }

  String _normalizeCuratedMatchKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'''[''’ʻ]'''), '')
        .replaceAll(RegExp(r'[!！?？・【】\[\]()（）]'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _confirmAndRegister(PodcastShow show) async {
    if (_registeredShowIds.contains(show.id)) {
      await _handleTap(show);
      return;
    }

    final lang = appSettings.language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = AppColors.current;
        return AlertDialog(
          title: Text('おすすめ_登録確認'.tr(lang)),
          content: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: show.artworkUrl != null
                    ? Image.network(
                        show.artworkUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _dialogArtFallback(palette),
                      )
                    : _dialogArtFallback(palette),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  show.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('キャンセル'.tr(lang)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('登録する'.tr(lang)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await _handleTap(show);
  }

  Widget _dialogArtFallback(AppPalette palette) => Container(
    width: 56,
    height: 56,
    color: palette.cardBorder,
    child: Icon(Icons.podcasts, color: palette.textOnCardSecondary),
  );

  Future<void> _search() async {
    final lang = appSettings.language;
    final term = _searchController.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _searchService.search(term);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = '検索に失敗しました'.tr(lang);
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: Material(
        // TextField/IconButtonがMaterial祖先を必要とするため、単なる
        // Containerではなくこの画面のルートをMaterialにする。
        color: palette.scene,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                '番組を追加'.tr(lang),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnScenePrimary,
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle(palette, 'URLで追加'.tr(lang)),
              const SizedBox(height: 8),
              _buildUrlEntry(palette, lang),
              const SizedBox(height: 28),
              _sectionTitle(palette, '番組を検索'.tr(lang)),
              const SizedBox(height: 8),
              _buildSearchEntry(palette, lang),
              const SizedBox(height: 28),
              _sectionTitle(palette, 'おすすめ'.tr(lang)),
              const SizedBox(height: 4),
              Text(
                'おすすめ_セクション説明'.tr(lang),
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textOnSceneSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildCard(
                palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var gi = 0; gi < curatedPodcastGroups.length; gi++) ...[
                      if (gi > 0) ...[
                        const SizedBox(height: 8),
                        Divider(color: palette.cardBorder, height: 1),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        curatedPodcastGroups[gi].titleKey.tr(lang),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.textOnCardSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final query in curatedPodcastGroups[gi].queries)
                        CuratedShowCard(
                          title: query.titleKey.tr(lang),
                          subtitle: query.subtitleKey.tr(lang),
                          isLoading: _curatedLoadingId == query.id,
                          onTap: () => _searchCurated(query),
                        ),
                    ],
                  ],
                ),
              ),
              if (_curatedError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _curatedError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(AppPalette palette, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.textOnScenePrimary,
      ),
    );
  }

  Widget _buildUrlEntry(AppPalette palette, String lang) {
    return _buildCard(
      palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  style: TextStyle(
                    color: palette.textOnCardPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/feed.xml',
                    hintStyle: TextStyle(color: palette.textOnCardSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: palette.subpageBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addByUrl(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _urlLoading ? null : _addByUrl,
                icon: _urlLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAccent,
                        ),
                      )
                    : const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: palette.accentColor,
                ),
                color: palette.onAccent,
              ),
            ],
          ),
          if (_urlError != null) ...[
            const SizedBox(height: 8),
            Text(
              _urlError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchEntry(AppPalette palette, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          palette,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: palette.textOnCardPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: '番組名・キーワードで検索'.tr(lang),
                    hintStyle: TextStyle(color: palette.textOnCardSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: palette.subpageBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAccent,
                        ),
                      )
                    : const Icon(Icons.search),
                style: IconButton.styleFrom(
                  backgroundColor: palette.accentColor,
                ),
                color: palette.onAccent,
              ),
            ],
          ),
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 8),
          Text(
            _searchError!,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ],
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCard(
            palette,
            child: Column(
              children: [
                for (final show in _searchResults)
                  PodcastShowTile(
                    show: show,
                    isRegistered: _registeredShowIds.contains(show.id),
                    onTap: () => _handleTap(show),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(AppPalette palette, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: child,
    );
  }
}
