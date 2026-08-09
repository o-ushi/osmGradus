import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/podcast_episode.dart';
import '../models/podcast_show.dart';
import 'rss_date_parser.dart';

/// osmPodの `FeedParserService`（手書きXMLパーサー）に相当。
/// FlutterではFoundationのXMLParserの代わりに `xml` パッケージでRSSを読む。
class PodcastFeedService {
  /// RSSフィードのURLを直接入力して番組を追加するためのメソッド。
  /// osmPodの直接RSS追加と同じく、タイトル・アートワークはチャンネル情報から
  /// 取得し、取得できない場合はホスト名にフォールバックする。
  Future<PodcastShow> fetchShowMetadata(String feedUrl) async {
    final response = await http
        .get(Uri.parse(feedUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('フィードの取得に失敗しました (HTTP ${response.statusCode})');
    }

    final document = XmlDocument.parse(_decodeFeedBody(response));
    final channels = document.findAllElements('channel');
    final channel = channels.isEmpty ? null : channels.first;
    final title = channel == null ? null : _text(channel, 'title');
    final artwork = channel == null ? null : _channelArtwork(channel);

    return PodcastShow(
      id: feedUrl,
      title: title ?? Uri.parse(feedUrl).host,
      feedUrl: feedUrl,
      artworkUrl: artwork,
    );
  }

  String? _channelArtwork(XmlElement channel) {
    final itunesImage = _firstChild(
      channel,
      'itunes:image',
    )?.getAttribute('href');
    if (itunesImage != null) return itunesImage;
    final imageEl = _firstChild(channel, 'image');
    if (imageEl == null) return null;
    return _text(imageEl, 'url');
  }

  /// フィードURLからエピソード一覧を取得する。osmPodと同じく新着順に並んだ
  /// フィード先頭から最大[limit]件のみ読み込む（初回取り込み上限=50相当）。
  Future<List<PodcastEpisode>> fetchEpisodes(
    String showId,
    String showTitle,
    String feedUrl, {
    int limit = 50,
  }) async {
    final response = await http
        .get(Uri.parse(feedUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('フィードの取得に失敗しました (HTTP ${response.statusCode})');
    }

    final document = XmlDocument.parse(_decodeFeedBody(response));
    final items = document.findAllElements('item').take(limit);

    final episodes = <PodcastEpisode>[];
    for (final item in items) {
      final episode = _parseItem(showId, showTitle, item);
      if (episode != null) episodes.add(episode);
    }
    return episodes;
  }

  PodcastEpisode? _parseItem(String showId, String showTitle, XmlElement item) {
    final enclosure = _firstChild(item, 'enclosure');
    final audioUrl = enclosure?.getAttribute('url');
    if (audioUrl == null || audioUrl.isEmpty) return null;

    final title = _text(item, 'title') ?? '(タイトルなし)';
    final summaryRaw =
        _text(item, 'itunes:summary') ?? _text(item, 'description') ?? '';
    final artwork = _firstChild(item, 'itunes:image')?.getAttribute('href');

    return PodcastEpisode(
      showId: showId,
      showTitle: showTitle,
      audioUrl: audioUrl,
      title: _stripHtml(title),
      artworkUrl: artwork,
      publishedAt: parseRssPubDate(_text(item, 'pubDate')),
      summary: _stripHtml(summaryRaw),
      totalDuration: _parseDuration(_text(item, 'itunes:duration')),
    );
  }

  XmlElement? _firstChild(XmlElement parent, String qualifiedName) {
    final matches = parent.findElements(qualifiedName);
    return matches.isEmpty ? null : matches.first;
  }

  String? _text(XmlElement parent, String qualifiedName) {
    final el = _firstChild(parent, qualifiedName);
    final text = el?.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// `itunes:duration` は `HH:MM:SS` / `MM:SS` / 秒数のいずれかで来ることがある。
  Duration _parseDuration(String? raw) {
    if (raw == null) return Duration.zero;
    if (!raw.contains(':')) {
      return Duration(seconds: int.tryParse(raw) ?? 0);
    }
    final parts = raw.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration.zero;
  }

  String _stripHtml(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// `http.Response.body` は Content-Type に charset が無いと Latin-1 になる。
  /// NHK など多くの RSS は `application/xml`（charset なし）＋ UTF-8 本文なので、
  /// charset 未指定時は UTF-8 として読む。
  String _decodeFeedBody(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('charset=')) {
      return response.body;
    }
    return utf8.decode(response.bodyBytes);
  }
}
