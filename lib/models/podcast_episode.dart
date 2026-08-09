/// osmPodの `Episode` モデル相当。再生位置(`playbackPosition`)と総尺
/// (`totalDuration`)から進捗率を、`isPlayed`から再生済みかどうかを判定する。
class PodcastEpisode {
  PodcastEpisode({
    required this.showId,
    required this.showTitle,
    required this.audioUrl,
    required this.title,
    this.artworkUrl,
    this.publishedAt,
    this.summary = '',
    this.totalDuration = Duration.zero,
    this.playbackPosition = Duration.zero,
    this.isPlayed = false,
    this.isNew = false,
    this.isFavorite = false,
  });

  final String showId;
  final String showTitle;

  /// 音声URLをそのまま一意なIDとして使う（osmPodと同じ方針）。
  final String audioUrl;
  final String title;
  final String? artworkUrl;
  final DateTime? publishedAt;
  final String summary;
  final Duration totalDuration;
  final Duration playbackPosition;
  final bool isPlayed;

  /// 前回取得時点になかった新着エピソード（osmPodの `isNew` 相当）。
  /// 一覧でタップ、または再生開始した時点でfalseにする。
  final bool isNew;

  final bool isFavorite;

  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0;
    return (playbackPosition.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  bool get isInProgress => !isPlayed && playbackPosition > Duration.zero;

  PodcastEpisode copyWith({
    Duration? playbackPosition,
    bool? isPlayed,
    bool? isNew,
    bool? isFavorite,
  }) {
    return PodcastEpisode(
      showId: showId,
      showTitle: showTitle,
      audioUrl: audioUrl,
      title: title,
      artworkUrl: artworkUrl,
      publishedAt: publishedAt,
      summary: summary,
      totalDuration: totalDuration,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isPlayed: isPlayed ?? this.isPlayed,
      isNew: isNew ?? this.isNew,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) {
    return PodcastEpisode(
      showId: json['showId'] as String,
      showTitle: json['showTitle'] as String? ?? '',
      audioUrl: json['audioUrl'] as String,
      title: json['title'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'] as String),
      summary: json['summary'] as String? ?? '',
      totalDuration: Duration(
        milliseconds: json['totalDurationMs'] as int? ?? 0,
      ),
      playbackPosition: Duration(
        milliseconds: json['playbackPositionMs'] as int? ?? 0,
      ),
      isPlayed: json['isPlayed'] as bool? ?? false,
      isNew: json['isNew'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'showId': showId,
    'showTitle': showTitle,
    'audioUrl': audioUrl,
    'title': title,
    'artworkUrl': artworkUrl,
    'publishedAt': publishedAt?.toIso8601String(),
    'summary': summary,
    'totalDurationMs': totalDuration.inMilliseconds,
    'playbackPositionMs': playbackPosition.inMilliseconds,
    'isPlayed': isPlayed,
    'isNew': isNew,
    'isFavorite': isFavorite,
  };
}
