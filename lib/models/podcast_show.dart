/// osmPodの `Show` モデル相当（フィールドを最小限に絞った軽量版）。
class PodcastShow {
  const PodcastShow({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.artworkUrl,
  });

  /// フィードURLをそのまま一意なIDとして使う（osmPodの重複排除キーと同じ）。
  final String id;
  final String title;
  final String feedUrl;
  final String? artworkUrl;

  factory PodcastShow.fromJson(Map<String, dynamic> json) => PodcastShow(
    id: json['id'] as String,
    title: json['title'] as String,
    feedUrl: json['feedUrl'] as String,
    artworkUrl: json['artworkUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'feedUrl': feedUrl,
    'artworkUrl': artworkUrl,
  };
}
