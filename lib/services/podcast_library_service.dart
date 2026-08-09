import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/podcast_episode.dart';
import '../models/podcast_show.dart';

enum AutoplayOrder { newest, oldest, random }

/// osmPodの `EpisodeOrderOption`（並べ替えパネルの基準）に相当。
enum EpisodeSortCriterion { date, name }

/// osmPodのSwiftData永続化に相当する軽量版。低スペック端末での負荷を抑えるため、
/// SQLite/Isar等は使わずSharedPreferences（=UserDefaults相当）にJSONで保存する。
class PodcastLibraryService {
  static const _registeredShowsKey = 'podcast.registeredShows';
  static const _episodesCachePrefix = 'podcast.episodes.';
  static const _lastPlayingEpisodeKey = 'podcast.lastPlayingEpisodeAudioUrl';
  static const _expandedShowIdsKey = 'podcast.expandedShowIds';
  static const _autoplayEnabledKey = 'podcast.autoplayEnabled';
  static const _autoplayOrderKey = 'podcast.autoplayOrder';
  static const _episodeSortCriterionKey = 'podcast.episodeSortCriterion';
  static const _episodeSortAscendingKey = 'podcast.episodeSortAscending';

  Future<List<PodcastShow>> loadRegisteredShows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_registeredShowsKey) ?? const [];
    return raw
        .map((s) => PodcastShow.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  /// osmPodの `PodcastShowRegistration.register` と同じく、feedUrlで重複排除する。
  Future<List<PodcastShow>> registerShow(PodcastShow show) async {
    final prefs = await SharedPreferences.getInstance();
    final shows = await loadRegisteredShows();
    if (shows.any((s) => s.id == show.id)) return shows;
    final updated = [...shows, show];
    await prefs.setStringList(
      _registeredShowsKey,
      updated.map((s) => jsonEncode(s.toJson())).toList(),
    );
    return updated;
  }

  /// osmPodの「番組管理」画面の削除（確認ダイアログ付き）に相当。
  /// 番組本体だけでなく、エピソードキャッシュ・折りたたみ状態も一緒に破棄する。
  Future<List<PodcastShow>> unregisterShow(String showId) async {
    final prefs = await SharedPreferences.getInstance();
    final shows = await loadRegisteredShows();
    final updated = shows.where((s) => s.id != showId).toList();
    await prefs.setStringList(
      _registeredShowsKey,
      updated.map((s) => jsonEncode(s.toJson())).toList(),
    );
    await prefs.remove('$_episodesCachePrefix$showId');
    final expanded = await loadExpandedShowIds();
    expanded.remove(showId);
    await saveExpandedShowIds(expanded);
    return updated;
  }

  Future<void> cacheEpisodes(
    String showId,
    List<PodcastEpisode> episodes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_episodesCachePrefix$showId',
      episodes.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<List<PodcastEpisode>> loadCachedEpisodes(String showId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_episodesCachePrefix$showId') ?? const [];
    return raw
        .map(
          (s) => PodcastEpisode.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  /// 全登録番組のキャッシュ済みエピソードをまとめて返す（ランダム再生・自動再生の
  /// 候補探索に使う。osmPodの「全番組横断のオートプレイ候補探索」に相当）。
  Future<List<PodcastEpisode>> loadAllCachedEpisodes() async {
    final shows = await loadRegisteredShows();
    final all = <PodcastEpisode>[];
    for (final show in shows) {
      all.addAll(await loadCachedEpisodes(show.id));
    }
    return all;
  }

  /// 新しくフィードから取得したエピソード一覧に、保存済みの再生位置・再生済み
  /// フラグをマージする。以前のキャッシュに存在しなかった音声URLは新着
  /// （`isNew`）として扱う。ただし初回登録時（キャッシュが空）は新着扱いしない。
  Future<List<PodcastEpisode>> mergeWithSavedPlaybackState(
    String showId,
    List<PodcastEpisode> freshEpisodes,
  ) async {
    final cached = await loadCachedEpisodes(showId);
    final savedByUrl = {for (final e in cached) e.audioUrl: e};
    final isFirstFetch = cached.isEmpty;
    return freshEpisodes.map((e) {
      final saved = savedByUrl[e.audioUrl];
      if (saved == null) {
        return isFirstFetch ? e : e.copyWith(isNew: true);
      }
      return e.copyWith(
        playbackPosition: saved.playbackPosition,
        isPlayed: saved.isPlayed,
        isNew: saved.isNew,
      );
    }).toList();
  }

  Future<void> savePlaybackState(
    String showId,
    String audioUrl, {
    Duration? position,
    bool? isPlayed,
    bool? isNew,
    bool? isFavorite,
  }) async {
    final episodes = await loadCachedEpisodes(showId);
    final updated = episodes.map((e) {
      if (e.audioUrl != audioUrl) return e;
      return e.copyWith(
        playbackPosition: position,
        isPlayed: isPlayed,
        isNew: isNew,
        isFavorite: isFavorite,
      );
    }).toList();
    await cacheEpisodes(showId, updated);
  }

  /// 一覧タップ・再生開始時に新着フラグを下ろす（osmPodの `clearNewIndicator`）。
  Future<void> clearNewFlag(String showId, String audioUrl) =>
      savePlaybackState(showId, audioUrl, isNew: false);

  /// お気に入りのオン/オフを切り替える（osmPodの⭐️トグルに相当）。
  Future<bool> toggleFavorite(String showId, PodcastEpisode episode) async {
    final newValue = !episode.isFavorite;
    await savePlaybackState(showId, episode.audioUrl, isFavorite: newValue);
    return newValue;
  }

  Future<String?> loadLastPlayingEpisodeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPlayingEpisodeKey);
  }

  Future<void> saveLastPlayingEpisodeUrl(String? audioUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (audioUrl == null) {
      await prefs.remove(_lastPlayingEpisodeKey);
    } else {
      await prefs.setString(_lastPlayingEpisodeKey, audioUrl);
    }
  }

  /// エピソード一覧の折りたたみ状態（osmPodの `expandedShowIDs` 相当）。
  /// 展開中の番組IDの集合として持ち、端末再起動後も復元される。
  Future<Set<String>> loadExpandedShowIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_expandedShowIdsKey) ?? const []).toSet();
  }

  Future<void> saveExpandedShowIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_expandedShowIdsKey, ids.toList());
  }

  Future<bool> loadAutoplayEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoplayEnabledKey) ?? true;
  }

  Future<void> saveAutoplayEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplayEnabledKey, value);
  }

  Future<AutoplayOrder> loadAutoplayOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_autoplayOrderKey);
    return AutoplayOrder.values.firstWhere(
      (o) => o.name == raw,
      orElse: () => AutoplayOrder.newest,
    );
  }

  Future<void> saveAutoplayOrder(AutoplayOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoplayOrderKey, order.name);
  }

  /// エピソード一覧の並べ替え基準（osmPodの `episodeOrderOption`）。
  /// 日付 or 名前のどちらで並べるかを表す。既定は日付順。
  Future<EpisodeSortCriterion> loadEpisodeSortCriterion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_episodeSortCriterionKey);
    return EpisodeSortCriterion.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => EpisodeSortCriterion.date,
    );
  }

  Future<void> saveEpisodeSortCriterion(EpisodeSortCriterion criterion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_episodeSortCriterionKey, criterion.name);
  }

  /// 並べ替えの昇順/降順（osmPodの `episodeSortAscending`）。
  /// 基準（日付/名前）とは独立したフラグ。既定は降順（新しい順）。
  Future<bool> loadEpisodeSortAscending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_episodeSortAscendingKey) ?? false;
  }

  Future<void> saveEpisodeSortAscending(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_episodeSortAscendingKey, value);
  }
}
