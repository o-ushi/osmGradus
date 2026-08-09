import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/podcast_episode.dart';
import '../services/app_logger.dart';
import '../services/podcast_library_service.dart';

/// osmPodの `AudioPlayerService`（AVPlayerベース）のFlutter移植。
/// ロック画面/コントロールセンター連携は `audio_service` が担い、実際の再生は
/// `just_audio` が行う。再生/一時停止・シーク・定期保存・自動再生に加え、
/// osmPodが対処した「ロック画面の再生ボタンが実際の状態とズレる」不具合の
/// 修正ロジック（[_reassertPlaybackState]）も移植している。
class PodcastAudioHandler extends BaseAudioHandler with SeekHandler {
  PodcastAudioHandler(this._library) {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        AppLogger.instance.log('Podcast再生エラー: $e', level: LogLevel.error);
      },
    );
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _handleCompleted();
    });
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.playing) _persistPosition();
    });
  }

  final PodcastLibraryService _library;
  final AudioPlayer _player = AudioPlayer();
  late final Timer _saveTimer;
  Timer? _reassertTimer;

  /// osmPodの `forceNowPlayingRateEdge` に合わせた再アサート間隔。
  static const _reassertDelays = [
    Duration(milliseconds: 80),
    Duration(milliseconds: 200),
    Duration(milliseconds: 400),
    Duration(milliseconds: 800),
  ];

  PodcastEpisode? _currentEpisode;
  PodcastEpisode? get currentEpisode => _currentEpisode;

  /// 現在の番組の全エピソード（公開日降順の「次のエピソード」判定に使う）。
  List<PodcastEpisode> queueEpisodes = [];

  bool isRandomModeEnabled = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;
  bool get isPlaying => _player.playing;

  bool isCurrentEpisode(PodcastEpisode episode) =>
      _currentEpisode?.audioUrl == episode.audioUrl;

  /// osmPodの `play(episode:)` 相当。同じエピソードなら再生/一時停止を切り替え、
  /// 別のエピソードなら再生を開始し、保存済みの再生位置までシークする。
  Future<void> loadAndPlay(
    PodcastEpisode episode, {
    List<PodcastEpisode>? queue,
  }) async {
    if (isCurrentEpisode(episode)) {
      await (_player.playing ? pause() : play());
      return;
    }
    if (queue != null) queueEpisodes = queue;
    _currentEpisode = episode;
    mediaItem.add(_mediaItemFor(episode));
    await _library.clearNewFlag(episode.showId, episode.audioUrl);

    try {
      await _player.setUrl(episode.audioUrl);
      if (episode.playbackPosition > Duration.zero) {
        await _player.seek(episode.playbackPosition);
      }
      await _player.play();
      await _library.saveLastPlayingEpisodeUrl(episode.audioUrl);
      _reassertPlaybackState(expectedPlaying: true);
      AppLogger.instance.log('再生開始: ${episode.title}');
    } catch (e) {
      AppLogger.instance.log('再生開始に失敗しました: $e', level: LogLevel.error);
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    _reassertPlaybackState(expectedPlaying: true);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _persistPosition();
    _reassertPlaybackState(expectedPlaying: false);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() => _seekBy(const Duration(seconds: 15));

  @override
  Future<void> rewind() => _seekBy(const Duration(seconds: -15));

  @override
  Future<void> skipToNext() => skipToNextInQueue();

  /// ヘッダーのスキップボタン用。現在の番組内で公開日が次のエピソードへ進む。
  Future<void> skipToNextInQueue() async {
    final current = _currentEpisode;
    if (current == null || queueEpisodes.isEmpty) return;
    final sorted = [...queueEpisodes]
      ..sort(
        (a, b) => (a.publishedAt ?? DateTime(0)).compareTo(
          b.publishedAt ?? DateTime(0),
        ),
      );
    final index = sorted.indexWhere((e) => e.audioUrl == current.audioUrl);
    if (index == -1 || index + 1 >= sorted.length) return;
    await loadAndPlay(sorted[index + 1], queue: sorted);
  }

  Future<void> _seekBy(Duration delta) async {
    final target = _player.position + delta;
    final clamped = target < Duration.zero ? Duration.zero : target;
    await _player.seek(clamped);
  }

  @override
  Future<void> stop() async {
    await _persistPosition();
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// osmPodの `scheduleNowPlayingReassert` / `forceNowPlayingRateEdge` の移植。
  ///
  /// OS側（AVPlayerのKVOやiOSのNowPlayingInfo自動更新）が非同期に再生状態を
  /// 上書きし、ロック画面/コントロールセンターの再生ボタンが実際の再生状態と
  /// ズレる不具合をosmPodで踏んだことがある。対策として、意図した`playing`状態を
  /// 80/200/400/800msの間隔で複数回再送信し、OS側の遅れた上書きを打ち消す。
  /// 途中で実際の再生状態が変わっていたら（ユーザー操作等）即座に中断する。
  void _reassertPlaybackState({required bool expectedPlaying}) {
    _reassertTimer?.cancel();
    var index = 0;
    void scheduleNext() {
      if (index >= _reassertDelays.length) return;
      final delay = _reassertDelays[index++];
      _reassertTimer = Timer(delay, () {
        if (_player.playing != expectedPlaying) return;
        playbackState.add(
          playbackState.value.copyWith(playing: expectedPlaying),
        );
        scheduleNext();
      });
    }

    scheduleNext();
  }

  Future<void> _persistPosition() async {
    final episode = _currentEpisode;
    if (episode == null) return;
    await _library.savePlaybackState(
      episode.showId,
      episode.audioUrl,
      position: _player.position,
    );
  }

  Future<void> _handleCompleted() async {
    final episode = _currentEpisode;
    if (episode == null) return;
    await _library.savePlaybackState(
      episode.showId,
      episode.audioUrl,
      position: Duration.zero,
      isPlayed: true,
    );
    AppLogger.instance.log('再生完了: ${episode.title}');
    await _autoPlayNext(episode);
  }

  /// osmPodの `enqueueNextEpisode` の優先順位を移植:
  /// ランダムモード → 同じ番組内で公開日順の次のエピソード → 自動再生設定 → 停止。
  Future<void> _autoPlayNext(PodcastEpisode finished) async {
    if (isRandomModeEnabled) {
      final next = await _pickRandomUnplayed(exclude: finished.audioUrl);
      if (next != null) await loadAndPlay(next);
      return;
    }

    final sameShow =
        queueEpisodes.where((e) => e.showId == finished.showId).toList()..sort(
          (a, b) => (a.publishedAt ?? DateTime(0)).compareTo(
            b.publishedAt ?? DateTime(0),
          ),
        );
    final currentIndex = sameShow.indexWhere(
      (e) => e.audioUrl == finished.audioUrl,
    );
    if (currentIndex != -1 && currentIndex + 1 < sameShow.length) {
      await loadAndPlay(sameShow[currentIndex + 1], queue: sameShow);
      return;
    }

    final autoplayEnabled = await _library.loadAutoplayEnabled();
    if (!autoplayEnabled) return;

    final order = await _library.loadAutoplayOrder();
    final all = await _library.loadAllCachedEpisodes();
    final unplayed = all.where((e) => !e.isPlayed).toList();
    if (unplayed.isEmpty) return;

    switch (order) {
      case AutoplayOrder.newest:
        unplayed.sort(
          (a, b) => (b.publishedAt ?? DateTime(0)).compareTo(
            a.publishedAt ?? DateTime(0),
          ),
        );
      case AutoplayOrder.oldest:
        unplayed.sort(
          (a, b) => (a.publishedAt ?? DateTime(0)).compareTo(
            b.publishedAt ?? DateTime(0),
          ),
        );
      case AutoplayOrder.random:
        unplayed.shuffle();
    }
    await loadAndPlay(unplayed.first);
  }

  Future<PodcastEpisode?> _pickRandomUnplayed({required String exclude}) async {
    final all = await _library.loadAllCachedEpisodes();
    final candidates = all
        .where((e) => !e.isPlayed && e.audioUrl != exclude)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.shuffle();
    return candidates.first;
  }

  MediaItem _mediaItemFor(PodcastEpisode episode) {
    return MediaItem(
      id: episode.audioUrl,
      title: episode.title,
      artist: episode.showTitle,
      duration: episode.totalDuration > Duration.zero
          ? episode.totalDuration
          : null,
      artUri: episode.artworkUrl != null
          ? Uri.tryParse(episode.artworkUrl!)
          : null,
    );
  }

  Future<void> disposePlayer() async {
    _saveTimer.cancel();
    _reassertTimer?.cancel();
    await _persistPosition();
    await _player.dispose();
  }
}
