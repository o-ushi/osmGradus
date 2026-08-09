import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/podcast_show.dart';

/// osmPodの `ITunesPodcastSearchService` の移植。iTunes Search APIを直接叩き、
/// 任意のキーワードから番組（フィードURLつき）を検索する。SDKは使わず、
/// プレーンなHTTP + JSONデコードのみ（osmPodと同じ方針）。
class ITunesPodcastSearchService {
  Future<List<PodcastShow>> search(String term) async {
    final query = term.trim();
    if (query.isEmpty) return [];

    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'entity': 'podcast',
      'limit': '25',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('検索に失敗しました (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? const [];

    final shows = <PodcastShow>[];
    for (final raw in results) {
      final item = raw as Map<String, dynamic>;
      final feedUrl = item['feedUrl'] as String?;
      if (feedUrl == null || feedUrl.isEmpty) continue;
      shows.add(
        PodcastShow(
          id: feedUrl,
          title: (item['collectionName'] as String?) ?? feedUrl,
          feedUrl: feedUrl,
          artworkUrl:
              (item['artworkUrl600'] as String?) ??
              (item['artworkUrl100'] as String?),
        ),
      );
    }
    return shows;
  }
}
