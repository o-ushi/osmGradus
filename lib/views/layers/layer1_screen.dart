import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, audioHandler;
import '../../models/podcast_episode.dart';
import '../../models/podcast_show.dart';
import '../../services/app_logger.dart';
import '../../services/podcast_feed_service.dart';
import '../../services/podcast_library_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/episode_jump_bar.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/podcast_toolbar.dart';
import '../podcast/add_show_screen.dart';
import '../podcast/episode_row.dart';
import '../podcast/episode_sort_sheet.dart';

/// レイヤーⅠ：日本語を聞いても意味が分からない。
/// - Podcast（osmPodのライブラリ画面・番組登録・再生・自動再生・ロック画面連携
///   ロジックを移植）
///
/// osmPodのライブラリ画面と同じく、登録済み番組はそれぞれ独立したカードとして
/// 縦に並び、折りたたみ状態と収録エピソード数に応じてカードの高さが変わる。
class Layer1Screen extends StatefulWidget {
  const Layer1Screen({super.key, this.onBackToModeSelect});

  /// レイヤーⅠの2択（語彙／耳慣れ）へ戻る。未指定なら戻るボタンを出さない。
  final VoidCallback? onBackToModeSelect;

  @override
  State<Layer1Screen> createState() => Layer1ScreenState();
}

class Layer1ScreenState extends State<Layer1Screen> {
  final _library = PodcastLibraryService();
  final _feedService = PodcastFeedService();

  /// 番組ごとのヘッダー（番組名）/末尾エピソード行に付けるアンカー。
  /// ジャンプボタンはスクロール位置の計算ではなく、この行そのものへ
  /// `Scrollable.ensureVisible`する（osmPodの`scrollProxy.scrollTo(anchorID:)`
  /// と同じ考え方）。「上端」は先頭エピソードではなく番組名（ヘッダー）を
  /// 基準にする。先頭エピソードを基準にすると、ヘッダーがその上に隠れてしまう。
  final Map<String, GlobalKey> _headerKeys = {};
  final Map<String, GlobalKey> _lastEpisodeKeys = {};

  List<PodcastShow> _registeredShows = [];
  final Map<String, List<PodcastEpisode>> _episodesByShow = {};
  final Map<String, bool> _loadingByShow = {};
  final Map<String, String?> _errorByShow = {};
  Set<String> _expandedShowIds = {};

  /// 直近で展開した番組。画面下部に固定表示するジャンプバーはこの番組の
  /// 先頭/末尾エピソードだけを対象にする。
  String? _focusedShowId;
  EpisodeSortCriterion _sortCriterion = EpisodeSortCriterion.date;
  bool _sortAscending = false;

  static const _jumpBarThreshold = 10;

  /// 起動画面の＋から番組を追加したあと、一覧を最新化する。
  Future<void> reloadLibrary() => _bootstrap();

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _bootstrap() async {
    final shows = await _library.loadRegisteredShows();
    final expanded = await _library.loadExpandedShowIds();
    final criterion = await _library.loadEpisodeSortCriterion();
    final ascending = await _library.loadEpisodeSortAscending();
    if (!mounted) return;
    setState(() {
      _registeredShows = shows;
      _expandedShowIds = expanded;
      _focusedShowId = expanded.isEmpty ? null : expanded.first;
      _sortCriterion = criterion;
      _sortAscending = ascending;
    });
    for (final show in shows) {
      unawaited(_loadShow(show));
    }
  }

  Future<void> _loadShow(PodcastShow show) async {
    final cached = await _library.loadCachedEpisodes(show.id);
    if (!mounted) return;
    setState(() {
      _episodesByShow[show.id] = cached;
      _loadingByShow[show.id] = cached.isEmpty;
    });

    try {
      final fresh = await _feedService.fetchEpisodes(
        show.id,
        show.title,
        show.feedUrl,
      );
      final merged = await _library.mergeWithSavedPlaybackState(show.id, fresh);
      await _library.cacheEpisodes(show.id, merged);
      if (!mounted) return;
      setState(() {
        _episodesByShow[show.id] = merged;
        _loadingByShow[show.id] = false;
        _errorByShow[show.id] = null;
      });
    } catch (e) {
      AppLogger.instance.log('番組の読み込みに失敗しました: $e', level: LogLevel.error);
      if (!mounted) return;
      setState(() {
        _loadingByShow[show.id] = false;
        _errorByShow[show.id] = cached.isEmpty ? '番組の読み込みに失敗しました' : null;
      });
    }
  }

  Future<void> _openShowPicker() async {
    await AddShowScreen.push(
      context,
      registeredShowIds: _registeredShows.map((s) => s.id).toSet(),
      onSelect: (show) async {
        final updated = await _library.registerShow(show);
        if (!mounted) return;
        setState(() => _registeredShows = updated);
        await _loadShow(show);
      },
      onDelete: (show) async {
        final updated = await _library.unregisterShow(show.id);
        if (!mounted) return;
        setState(() {
          _registeredShows = updated;
          _episodesByShow.remove(show.id);
          _loadingByShow.remove(show.id);
          _errorByShow.remove(show.id);
          _expandedShowIds.remove(show.id);
          if (_focusedShowId == show.id) _focusedShowId = null;
        });
      },
    );
  }

  /// 「＋」長押し：番組追加・エピソード選択の2ステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅠ_ポッドキャスト_使い方_番組追加'.tr(lang), icon: Icons.add),
        LayerHelpLine(text: 'レイヤーⅠ_ポッドキャスト_使い方_エピソード選択'.tr(lang)),
      ],
    );
  }

  void _toggleFold(String showId) {
    setState(() {
      if (_expandedShowIds.contains(showId)) {
        _expandedShowIds.remove(showId);
        if (_focusedShowId == showId) _focusedShowId = null;
      } else {
        _expandedShowIds.add(showId);
        _focusedShowId = showId;
      }
    });
    _library.saveExpandedShowIds(_expandedShowIds);
  }

  Future<void> _playEpisode(PodcastEpisode episode) async {
    final queue = _episodesByShow[episode.showId] ?? [episode];
    await audioHandler.loadAndPlay(episode, queue: queue);
    // isNewが折れた最新状態をローカルにも反映する。
    if (!mounted) return;
    setState(() {
      final list = _episodesByShow[episode.showId];
      if (list == null) return;
      _episodesByShow[episode.showId] = list
          .map(
            (e) =>
                e.audioUrl == episode.audioUrl ? e.copyWith(isNew: false) : e,
          )
          .toList();
    });
  }

  Future<void> _toggleFavorite(PodcastEpisode episode) async {
    final newValue = await _library.toggleFavorite(episode.showId, episode);
    if (!mounted) return;
    setState(() {
      final list = _episodesByShow[episode.showId];
      if (list == null) return;
      _episodesByShow[episode.showId] = list
          .map(
            (e) => e.audioUrl == episode.audioUrl
                ? e.copyWith(isFavorite: newValue)
                : e,
          )
          .toList();
    });
  }

  Future<void> _openSortSheet() async {
    await EpisodeSortSheet.show(
      context,
      criterion: _sortCriterion,
      ascending: _sortAscending,
      onChanged: (criterion, ascending) async {
        await _library.saveEpisodeSortCriterion(criterion);
        await _library.saveEpisodeSortAscending(ascending);
        if (!mounted) return;
        setState(() {
          _sortCriterion = criterion;
          _sortAscending = ascending;
        });
      },
    );
  }

  void _toggleRandom() {
    setState(
      () =>
          audioHandler.isRandomModeEnabled = !audioHandler.isRandomModeEnabled,
    );
  }

  /// osmPodの `Show.sortedEpisodes` に相当。基準（日付/名前）と昇順フラグの
  /// 2軸で並べ替える。
  List<PodcastEpisode> _sortedEpisodesFor(String showId) {
    final sorted = [...?_episodesByShow[showId]];
    sorted.sort((a, b) {
      final int comparison;
      switch (_sortCriterion) {
        case EpisodeSortCriterion.date:
          final dateA = a.publishedAt ?? DateTime(0);
          final dateB = b.publishedAt ?? DateTime(0);
          comparison = dateA.compareTo(dateB);
        case EpisodeSortCriterion.name:
          comparison = a.title.compareTo(b.title);
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  GlobalKey _headerKeyFor(String showId) =>
      _headerKeys.putIfAbsent(showId, () => GlobalKey());

  GlobalKey _lastEpisodeKeyFor(String showId) =>
      _lastEpisodeKeys.putIfAbsent(showId, () => GlobalKey());

  /// ページ全体を横断する`ScrollController.jumpTo`は、他の番組をまたいで
  /// 全く関係ない位置まで飛んでしまう（複数番組が展開されている場合に破綻する）。
  /// 代わりに、その番組のヘッダー/末尾エピソード行そのものへスクロールする。
  void _jumpToShowTop(String showId) {
    final context = _headerKeyFor(showId).currentContext;
    if (context != null) Scrollable.ensureVisible(context, alignment: 0);
  }

  void _jumpToShowBottom(String showId) {
    final context = _lastEpisodeKeyFor(showId).currentContext;
    if (context != null) Scrollable.ensureVisible(context, alignment: 1);
  }

  Future<void> _shareLog() async {
    final text = AppLogger.instance.exportAsText();
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'osmGradus ログ'),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PodcastToolbar(
                      onSkipNext: () => audioHandler.skipToNext(),
                      isRandomEnabled: audioHandler.isRandomModeEnabled,
                      onToggleRandom: _toggleRandom,
                      onOpenSort: _openSortSheet,
                      onAddShow: _openShowPicker,
                      onAddShowLongPress: _showUsageHelp,
                      showPlaybackControls: _registeredShows.isNotEmpty,
                    ),
                  ),
                  if (AppLogger.instance.developerModeEnabled) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _shareLog,
                      icon: Icon(
                        Icons.bug_report,
                        color: palette.textOnScenePrimary,
                      ),
                      tooltip: 'ログを共有'.tr(lang),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(palette, lang)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette palette, String lang) {
    if (_registeredShows.isEmpty) {
      return _EmptyPrompt(lang: lang);
    }

    final focusedShowId = _focusedShowId;
    final showJumpBar =
        focusedShowId != null &&
        _expandedShowIds.contains(focusedShowId) &&
        (_episodesByShow[focusedShowId]?.length ?? 0) >= _jumpBarThreshold;

    return Stack(
      children: [
        StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, mediaSnapshot) {
            return StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, playbackSnapshot) {
                return ListView.separated(
                  itemCount: _registeredShows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildShowCard(
                    palette,
                    lang,
                    _registeredShows[index],
                    currentUrl: mediaSnapshot.data?.id,
                    isPlaying: playbackSnapshot.data?.playing ?? false,
                    livePosition: playbackSnapshot.data?.updatePosition,
                  ),
                );
              },
            );
          },
        ),
        // カードの中に置くとエピソード数だけ長くなるカードの最下部まで一緒に
        // スクロールしてしまい、実質画面外に隠れて使えなくなる。画面（ここでは
        // Podcastセクションの表示領域）に固定したフローティングバーにし、
        // 直近で展開した番組の先頭/末尾エピソードだけを対象にする。
        if (showJumpBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: EpisodeJumpBar(
                onJumpToTop: () => _jumpToShowTop(focusedShowId),
                onJumpToBottom: () => _jumpToShowBottom(focusedShowId),
              ),
            ),
          ),
      ],
    );
  }

  /// osmPodのライブラリ画面と同じく、番組ごとに独立したカード。折りたたみ時は
  /// 見出し1行分、展開時はエピソード数に応じて自然に高さが伸びる
  /// （固定高さを持たせず、`Column` の内容量にそのまま追従させている）。
  Widget _buildShowCard(
    AppPalette palette,
    String lang,
    PodcastShow show, {
    required String? currentUrl,
    required bool isPlaying,
    required Duration? livePosition,
  }) {
    final isExpanded = _expandedShowIds.contains(show.id);
    final loading = _loadingByShow[show.id] ?? false;
    final error = _errorByShow[show.id];
    final episodes = _sortedEpisodesFor(show.id);
    // 末尾にアンカーキーを付けるかどうか。しきい値未満だとジャンプバー自体を
    // 出さないため不要（キーの使い回しで重複が起きるのも避けられる）。
    final needsAnchors = episodes.length >= _jumpBarThreshold;

    return _buildCard(
      palette,
      key: ValueKey('podcast_show_card_${show.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: _headerKeyFor(show.id),
            child: _buildShowHeader(palette, show, isExpanded, episodes.length),
          ),
          if (isExpanded)
            Divider(height: 1, thickness: 1, color: palette.cardBorder),
          if (isExpanded && loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: palette.accentColor),
              ),
            ),
          if (isExpanded && !loading && error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error.tr(lang),
                style: TextStyle(color: palette.textOnCardSecondary),
              ),
            ),
          if (isExpanded && !loading && error == null && episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '配信中のエピソードがありません'.tr(lang),
                style: TextStyle(color: palette.textOnCardSecondary),
              ),
            ),
          if (isExpanded)
            for (var i = 0; i < episodes.length; i++) ...[
              Builder(
                builder: (context) {
                  final episode = episodes[i];
                  final isCurrent = currentUrl == episode.audioUrl;
                  final displayEpisode = isCurrent
                      ? episode.copyWith(playbackPosition: livePosition)
                      : episode;
                  final row = EpisodeRow(
                    episode: displayEpisode,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    onTap: () => _playEpisode(episode),
                    onToggleFavorite: () => _toggleFavorite(episode),
                  );
                  if (!needsAnchors) return row;
                  if (i == episodes.length - 1) {
                    return KeyedSubtree(
                      key: _lastEpisodeKeyFor(show.id),
                      child: row,
                    );
                  }
                  return row;
                },
              ),
              if (i != episodes.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: palette.cardBorder,
                ),
            ],
        ],
      ),
    );
  }

  /// osmPodのpastelフレームを模したカード外枠。左端にアクセントの縦帯を出す。
  ///
  /// `Border`は辺ごとに異なる色を指定すると`borderRadius`と併用できない
  /// （例外になる）ため、外枠は単色の枠にし、アクセント帯は内側の子要素として
  /// 別に描画する。
  Widget _buildCard(AppPalette palette, {Key? key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      // ListView内ではRowの高さが無限大の制約を受けるため、IntrinsicHeightで
      // 子の実サイズから高さを確定させてからstretchさせる。
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: palette.cardAccent),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildShowHeader(
    AppPalette palette,
    PodcastShow show,
    bool isExpanded,
    int episodeCount,
  ) {
    return InkWell(
      onTap: () => _toggleFold(show.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                show.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: palette.textOnCardPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.podcasts, size: 48, color: palette.textOnScenePrimary),
          const SizedBox(height: 12),
          Text(
            '番組を登録してください'.tr(lang),
            style: TextStyle(fontSize: 15, color: palette.textOnScenePrimary),
          ),
        ],
      ),
    );
  }
}
