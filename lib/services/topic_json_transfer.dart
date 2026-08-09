import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/topic_category.dart';
import 'topic_service.dart';

/// [TopicJsonTransfer.importFromContent]の結果。
class TopicJsonImportResult {
  const TopicJsonImportResult({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

/// レイヤーⅡ〜Ⅳの「お題を追加」シートから使う、取り込み済みお題単体の
/// JSONインポート/エクスポート（Step 10）。
///
/// 既存の「AIで追加」（[TopicImportScreen]、Chrome AIの回答をそのまま
/// クリップボードから貼り付ける【見出し】区切りテキスト形式）とは別の、
/// ファイル入出力用の構造化JSON形式。
///
/// [GradusBackup]のフルバックアップが持つ`topics`節（カテゴリ→文字列配列の
/// マップ）とは異なる形（1件ずつ`category`/`text`を持つ配列）だが、
/// どちらも[TopicService]の同じ取り込み済みお題ストレージを読み書きする
/// ため、データソースが二重になることはない。
abstract final class TopicJsonTransfer {
  static const formatVersion = 1;
  static const filePrefix = 'osmGradus_topics_';

  /// エクスポート対象のカテゴリ（[TopicCategory.random]は取り込み専用の
  /// ストアを持たない派生カテゴリのため対象外）。
  static const _categories = [
    TopicCategory.daily,
    TopicCategory.business,
    TopicCategory.situational,
  ];

  static Future<int> itemCount() async {
    final service = TopicService();
    var total = 0;
    for (final category in _categories) {
      total += (await service.loadImported(category)).length;
    }
    return total;
  }

  /// 組み込みのお題バンクは含めず、取り込み済みお題だけを書き出す。
  static Future<String> buildExportJson() async {
    final service = TopicService();
    final topics = <Map<String, String>>[];
    for (final category in _categories) {
      for (final text in await service.loadImported(category)) {
        topics.add({'category': category.storageKey, 'text': text});
      }
    }
    final bundle = {'version': formatVersion, 'topics': topics};
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  static Future<File> writeExportFile() async {
    final json = await buildExportJson();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .substring(0, 15);
    final file = File('${dir.path}/$filePrefix$stamp.json');
    await file.writeAsString(json, flush: true);
    return file;
  }

  /// `{ "version": 1, "topics": [ { "category": "daily", "text": "..." }, ... ] }`
  /// 形式を読み込み、[TopicService.importTopics]で重複を除いてマージする。
  /// 壊れたJSON・不正な形はすべて[FormatException]にまとめて投げる
  /// （呼び出し側でエラーダイアログを出す）。カテゴリ不明・空文字など
  /// 個々の不正な要素は例外にせず読み飛ばす。
  static Future<TopicJsonImportResult> importFromContent(String raw) async {
    final content = raw.trim().replaceFirst('﻿', '');
    if (content.isEmpty) {
      throw const FormatException('empty file');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid format');
    }
    final topicsRaw = decoded['topics'];
    if (topicsRaw is! List) {
      throw const FormatException('missing topics');
    }

    final byCategory = <TopicCategory, List<String>>{
      for (final category in _categories) category: [],
    };
    for (final item in topicsRaw) {
      if (item is! Map) continue;
      final categoryKey = item['category'];
      final text = item['text'];
      if (categoryKey is! String || text is! String) continue;
      final category = _categoryFromStorageKey(categoryKey);
      if (category == null) continue;
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      byCategory[category]!.add(trimmed);
    }

    final service = TopicService();
    var added = 0;
    var skipped = 0;
    for (final category in _categories) {
      final items = byCategory[category]!;
      if (items.isEmpty) continue;
      final addedCount = await service.importTopics(category, items);
      added += addedCount;
      skipped += items.length - addedCount;
    }
    return TopicJsonImportResult(added: added, skipped: skipped);
  }

  static TopicCategory? _categoryFromStorageKey(String key) => switch (key) {
    'daily' => TopicCategory.daily,
    'business' => TopicCategory.business,
    'situational' => TopicCategory.situational,
    _ => null,
  };
}
