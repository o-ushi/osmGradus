/// 日本語学習者向けのおすすめ番組。番組名・アートワークはアプリに埋め込まず、
/// 説明カードをタップしたときに iTunes Search API で検索する。
///
/// 「日本語Podcast【日本とベトナムを比べてみよう！】」は iTunes Search API
/// で RSS 付き番組として見つからなかったため未掲載（YouTube 等のみの可能性）。
class CuratedPodcastQuery {
  const CuratedPodcastQuery({
    required this.id,
    required this.searchTerm,
    required this.titleKey,
    required this.subtitleKey,
  });

  final String id;
  final String searchTerm;
  final String titleKey;
  final String subtitleKey;
}

class CuratedPodcastGroup {
  const CuratedPodcastGroup({
    required this.titleKey,
    required this.queries,
  });

  final String titleKey;
  final List<CuratedPodcastQuery> queries;
}

const List<CuratedPodcastGroup> curatedPodcastGroups = [
  CuratedPodcastGroup(
    titleKey: 'おすすめ_グループ_初心者',
    queries: [
      CuratedPodcastQuery(
        id: 'nhk-vi-lesson',
        searchTerm: 'Cùng nhau học tiếng Nhật NHK WORLD',
        titleKey: 'おすすめ_NHK_タイトル',
        subtitleKey: 'おすすめ_NHK_説明',
      ),
      CuratedPodcastQuery(
        id: 'classroom',
        searchTerm: 'あかね的日本語教室',
        titleKey: 'おすすめ_教室_タイトル',
        subtitleKey: 'おすすめ_教室_説明',
      ),
      CuratedPodcastQuery(
        id: 'noriko',
        searchTerm: 'Learn Japanese with Noriko',
        titleKey: 'おすすめ_Noriko_タイトル',
        subtitleKey: 'おすすめ_Noriko_説明',
      ),
      CuratedPodcastQuery(
        id: 'beginner-slow',
        searchTerm: 'Nihongo con Teppei for Beginners',
        titleKey: 'おすすめ_ゆっくり_タイトル',
        subtitleKey: 'おすすめ_ゆっくり_説明',
      ),
    ],
  ),
  CuratedPodcastGroup(
    titleKey: 'おすすめ_グループ_リスニング',
    queries: [
      CuratedPodcastQuery(
        id: 'yuyu',
        searchTerm: 'YUYUの日本語Podcast【Japanese Podcast】',
        titleKey: 'おすすめ_Yuyu_タイトル',
        subtitleKey: 'おすすめ_Yuyu_説明',
      ),
      CuratedPodcastQuery(
        id: 'conversation',
        searchTerm: "Let's Talk in Japanese!",
        titleKey: 'おすすめ_会話_タイトル',
        subtitleKey: 'おすすめ_会話_説明',
      ),
    ],
  ),
];
