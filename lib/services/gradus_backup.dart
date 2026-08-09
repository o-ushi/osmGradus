import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/long_article.dart';
import '../models/podcast_episode.dart';
import '../models/podcast_show.dart';
import '../models/pronunciation_exercise.dart';
import '../models/saved_pronunciation_check.dart';
import '../models/saved_scoring_result.dart';
import '../models/saved_vocabulary_check.dart';
import '../models/topic_category.dart';
import '../models/vocabulary_entry.dart';
import '../services/dashboard_advice_storage.dart';
import '../services/long_article_service.dart';
import '../services/podcast_library_service.dart';
import '../services/pronunciation_check_storage.dart';
import '../services/pronunciation_exercise_service.dart';
import '../services/scoring_result_storage.dart';
import '../services/topic_service.dart';
import '../services/vocabulary_check_storage.dart';
import '../services/vocabulary_service.dart';

/// お題の取り込み（[TopicService]）はカテゴリを問わず全件バックアップ対象に
/// なるが、「ランダム」は日常・ビジネスの取り込み分から都度合成される
/// 抽選専用カテゴリで、それ自体には取り込み先が無いため対象外。
const _backedUpTopicCategories = [
  TopicCategory.daily,
  TopicCategory.business,
  TopicCategory.situational,
];

/// 既に専用のマージ処理（重複除外・追記）を持つSharedPreferencesキー。
/// [GradusBackup.buildExportJson]の`preferences`欄からはこれらを除外する
/// （インポート側で常に最後に走る[_restorePreferences]がそのまま書き戻すと、
/// 各マージ処理が組み立てた「既存＋取り込み分」の結果を、取り込み側の生の
/// 値だけで上書きしてしまい、端末側だけにあったデータが消えてしまうため）。
Set<String> get _explicitlyMergedPrefKeys => {
  'layer4.scoringResults',
  'layer5.pronunciationChecks',
  'vocabulary.entries',
  'layer1Vocab.checks',
  'dashboard.advice',
  'longArticles.entries',
  for (final category in _backedUpTopicCategories)
    'topics.imported.${category.storageKey}',
  for (final category in PronunciationCategory.values)
    'pronunciation.imported.${category.storageKey}',
};

/// osmGenki の [DiaryBackup] パターンで、osmGradus のローカルデータを JSON 化する。
abstract final class GradusBackup {
  /// version 1: pronunciationChecksはid/createdAt/transcriptのみ（自由記述）。
  /// version 2: pronunciationChecksにsessionId/questions/evaluationを追加
  /// （レイヤーⅤの10問セッション＋5カテゴリ参考評価）。
  /// version 3: vocabularyChecks（レイヤーⅠ単語テスト履歴）・topics
  /// （レイヤーⅡ〜Ⅳの取り込み済みお題）・pronunciationExercises
  /// （レイヤーⅤの取り込み済み読上げ文）・dashboardAdvice（ダッシュボードの
  /// 総合アドバイス）を追加。
  /// version 4: longArticles（レイヤーⅠ「長文読解」で作成した長文一覧。
  /// osmCogitoからの機能移植の基盤データ）を追加。
  /// フィールドはすべて追加のみで既存フィールドの意味は変えていないため、
  /// 旧バージョンのバックアップもそのまま読み込める。
  static const formatVersion = 4;
  static const filePrefix = 'osmGradus_backup_';

  static Future<int> itemCount() async {
    final scoring = await ScoringResultStorage().loadAll();
    final pronunciation = await PronunciationCheckStorage().loadAll();
    final vocabulary = await VocabularyService().loadEntries();
    final vocabularyChecks = await VocabularyCheckStorage().loadAll();
    final shows = await PodcastLibraryService().loadRegisteredShows();
    final topics = await _loadImportedTopics();
    final pronunciationExercises = await PronunciationExerciseService()
        .loadAllImported();
    final advice = await DashboardAdviceStorage().load();
    final longArticles = await LongArticleService().loadArticles();
    final topicCount = topics.values.fold(0, (sum, list) => sum + list.length);
    return scoring.length +
        pronunciation.length +
        vocabulary.length +
        vocabularyChecks.length +
        shows.length +
        topicCount +
        pronunciationExercises.length +
        (advice == null ? 0 : 1) +
        longArticles.length;
  }

  static Future<Map<String, List<String>>> _loadImportedTopics() async {
    final service = TopicService();
    return {
      for (final category in _backedUpTopicCategories)
        category.storageKey: await service.loadImported(category),
    };
  }

  static Future<String> buildExportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final scoring = await ScoringResultStorage().loadAll();
    final pronunciation = await PronunciationCheckStorage().loadAll();
    final vocabulary = await VocabularyService().loadEntries();
    final vocabularyChecks = await VocabularyCheckStorage().loadAll();
    final library = PodcastLibraryService();
    final podcastShows = await library.loadRegisteredShows();
    final podcastEpisodes = await library.loadAllCachedEpisodes();
    final topics = await _loadImportedTopics();
    final pronunciationExercises = await PronunciationExerciseService()
        .loadAllImported();
    final advice = await DashboardAdviceStorage().load();
    final longArticles = await LongArticleService().loadArticles();
    final bundle = {
      'version': formatVersion,
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'scoringResults': scoring.map((e) => e.toJson()).toList(),
      'pronunciationChecks': pronunciation.map((e) => e.toJson()).toList(),
      'vocabulary': vocabulary.map((e) => e.toJson()).toList(),
      // レイヤーⅠ単語テストの履歴（built-in語も含めた出題内容とAI参考評価）。
      'vocabularyChecks': vocabularyChecks.map((e) => e.toJson()).toList(),
      'podcastShows': podcastShows.map((e) => e.toJson()).toList(),
      // 再生済み/再生中の位置を含む、番組ごとのエピソード状態
      // （osmPodのSwiftData永続化に相当する部分を丸ごと持ち出す）。
      'podcastEpisodes': podcastEpisodes.map((e) => e.toJson()).toList(),
      // レイヤーⅡ〜Ⅳ用に取り込んだお題（カテゴリごとの文字列一覧）。
      // 組み込みのお題バンクは含まない。
      'topics': topics,
      // レイヤーⅤ用に取り込んだベトナム語読上げ文。組み込み25文は含まない。
      'pronunciationExercises': pronunciationExercises
          .map((e) => e.toJson())
          .toList(),
      // ダッシュボードに表示中の総合アドバイス文言。
      'dashboardAdvice': ?advice,
      // レイヤーⅠ「長文読解」で作成した長文一覧。
      'longArticles': longArticles.map((e) => e.toJson()).toList(),
      'preferences': Map<String, Object?>.from(
        prefs
            .getKeys()
            .where((key) => !_explicitlyMergedPrefKeys.contains(key))
            .fold(<String, Object?>{}, (map, key) {
              map[key] = _readPref(prefs, key);
              return map;
            }),
      ),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  static Object? _readPref(SharedPreferences prefs, String key) {
    if (prefs.containsKey(key)) {
      final value = prefs.get(key);
      return value;
    }
    return null;
  }

  /// [buildExportJson]が書き出した`preferences`（言語・テーマ・読み上げ設定・
  /// タイマー音・同意状態など、SharedPreferencesの全キー）を書き戻す。
  /// 型はSharedPreferencesが扱える範囲（bool/int/double/String/文字列の配列）
  /// のみを復元し、それ以外の値は読み飛ばす。
  static Future<void> _restorePreferences(Object? raw) async {
    if (raw is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      switch (value) {
        case bool _:
          await prefs.setBool(key, value);
        case int _:
          await prefs.setInt(key, value);
        case double _:
          await prefs.setDouble(key, value);
        case String _:
          await prefs.setString(key, value);
        case List _:
          await prefs.setStringList(key, value.whereType<String>().toList());
      }
    }
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

  static Future<GradusImportResult> importFromContent(String raw) async {
    final content = raw.trim().replaceFirst('\uFEFF', '');
    if (content.isEmpty) {
      throw const FormatException('empty file');
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid format');
    }

    // versionが無い（osmGenki等の旧形式も含む）バックアップはv1として扱う。
    // pronunciationChecksのマージ自体はversionで分岐しない
    // （[SavedPronunciationCheck.fromJson]が新旧どちらの形状も許容するため）。
    final sourceVersion = (decoded['version'] as num?)?.toInt() ?? 1;

    var added = 0;
    var skipped = 0;

    final scoringList = decoded['scoringResults'];
    if (scoringList is List) {
      final tally = await _mergeScoring(scoringList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final pronunciationList = decoded['pronunciationChecks'];
    if (pronunciationList is List) {
      final tally = await _mergePronunciation(pronunciationList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final vocabularyList = decoded['vocabulary'];
    if (vocabularyList is List) {
      final tally = await _mergeVocabulary(vocabularyList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final vocabularyCheckList = decoded['vocabularyChecks'];
    if (vocabularyCheckList is List) {
      final tally = await _mergeVocabularyChecks(vocabularyCheckList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final topicsMap = decoded['topics'];
    if (topicsMap is Map) {
      final tally = await _mergeTopics(topicsMap);
      added += tally.added;
      skipped += tally.skipped;
    }

    final pronunciationExerciseList = decoded['pronunciationExercises'];
    if (pronunciationExerciseList is List) {
      final tally = await _mergePronunciationExercises(
        pronunciationExerciseList,
      );
      added += tally.added;
      skipped += tally.skipped;
    }

    final adviceTally = await _mergeDashboardAdvice(decoded['dashboardAdvice']);
    added += adviceTally.added;
    skipped += adviceTally.skipped;

    final longArticleList = decoded['longArticles'];
    if (longArticleList is List) {
      final tally = await _mergeLongArticles(longArticleList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final podcastShowList = decoded['podcastShows'];
    if (podcastShowList is List) {
      final tally = await _mergePodcastShows(podcastShowList);
      added += tally.added;
      skipped += tally.skipped;
    }

    final podcastEpisodeList = decoded['podcastEpisodes'];
    if (podcastEpisodeList is List) {
      final tally = await _mergePodcastEpisodes(podcastEpisodeList);
      added += tally.added;
      skipped += tally.skipped;
    }

    await _restorePreferences(decoded['preferences']);

    return GradusImportResult(
      added: added,
      skipped: skipped,
      sourceVersion: sourceVersion,
    );
  }
}

class GradusImportResult {
  const GradusImportResult({
    required this.added,
    required this.skipped,
    this.sourceVersion = GradusBackup.formatVersion,
  });

  final int added;
  final int skipped;

  /// インポート元バックアップのformatVersion（version省略時は1として扱う）。
  final int sourceVersion;
}

class _Tally {
  const _Tally({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

Future<_Tally> _mergeScoring(List<dynamic> jsonList) async {
  final storage = ScoringResultStorage();
  final existing = await storage.loadAll();
  final ids = existing.map((e) => e.id).toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = SavedScoringResult.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (ids.contains(parsed.id)) {
        skipped++;
        continue;
      }
      await storage.save(parsed);
      ids.add(parsed.id);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergePronunciation(List<dynamic> jsonList) async {
  final storage = PronunciationCheckStorage();
  final existing = await storage.loadAll();
  final ids = existing.map((e) => e.id).toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = SavedPronunciationCheck.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (ids.contains(parsed.id)) {
        skipped++;
        continue;
      }
      await storage.save(parsed);
      ids.add(parsed.id);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergeVocabulary(List<dynamic> jsonList) async {
  final service = VocabularyService();
  final existing = await service.loadEntries();
  final keys = existing.map((e) => '${e.word}\u0000${e.translation}').toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = VocabularyEntry.fromJson(Map<String, dynamic>.from(item));
      final key = '${parsed.word}\u0000${parsed.translation}';
      if (keys.contains(key)) {
        skipped++;
        continue;
      }
      await service.addEntry(
        parsed.word,
        parsed.translation,
        reading: parsed.reading,
        exampleSentence: parsed.exampleSentence,
        translationLang: parsed.translationLang,
        level: parsed.level,
      );
      keys.add(key);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergeLongArticles(List<dynamic> jsonList) async {
  final service = LongArticleService();
  final existing = await service.loadArticles();
  final keys = existing.map((e) => '${e.title}\u0000${e.body}').toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = LongArticle.fromJson(Map<String, dynamic>.from(item));
      final key = '${parsed.title}\u0000${parsed.body}';
      if (keys.contains(key)) {
        skipped++;
        continue;
      }
      await service.addArticle(
        title: parsed.title,
        body: parsed.body,
        isFavorite: parsed.isFavorite,
        generationKeyword: parsed.generationKeyword,
        generationJlptLevel: parsed.generationJlptLevel,
        generationLength: parsed.generationLength,
      );
      keys.add(key);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergeVocabularyChecks(List<dynamic> jsonList) async {
  final storage = VocabularyCheckStorage();
  final existing = await storage.loadAll();
  final ids = existing.map((e) => e.id).toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = SavedVocabularyCheck.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (ids.contains(parsed.id)) {
        skipped++;
        continue;
      }
      await storage.save(parsed);
      ids.add(parsed.id);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergeTopics(Map<dynamic, dynamic> raw) async {
  final service = TopicService();
  var added = 0;
  var skipped = 0;
  for (final category in _backedUpTopicCategories) {
    final value = raw[category.storageKey];
    if (value is! List) continue;
    final topics = value.whereType<String>().toList();
    final addedCount = await service.importTopics(category, topics);
    added += addedCount;
    skipped += topics.length - addedCount;
  }
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergePronunciationExercises(List<dynamic> jsonList) async {
  final service = PronunciationExerciseService();
  final parsed = <PronunciationExercise>[];
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) {
      skipped++;
      continue;
    }
    try {
      parsed.add(
        PronunciationExercise.fromJson(Map<String, dynamic>.from(item)),
      );
    } catch (_) {
      skipped++;
    }
  }
  final addedCounts = await service.importExercises(parsed);
  final added = addedCounts.values.fold(0, (sum, count) => sum + count);
  skipped += parsed.length - added;
  return _Tally(added: added, skipped: skipped);
}

Future<_Tally> _mergeDashboardAdvice(Object? raw) async {
  if (raw is! String || raw.trim().isEmpty) {
    return const _Tally(added: 0, skipped: 0);
  }
  final storage = DashboardAdviceStorage();
  final existing = await storage.load();
  if (existing != null && existing.isNotEmpty) {
    return const _Tally(added: 0, skipped: 1);
  }
  await storage.save(raw);
  return const _Tally(added: 1, skipped: 0);
}

Future<_Tally> _mergePodcastShows(List<dynamic> jsonList) async {
  final library = PodcastLibraryService();
  final existing = await library.loadRegisteredShows();
  final ids = existing.map((e) => e.id).toSet();
  var added = 0;
  var skipped = 0;
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = PodcastShow.fromJson(Map<String, dynamic>.from(item));
      if (ids.contains(parsed.id)) {
        skipped++;
        continue;
      }
      await library.registerShow(parsed);
      ids.add(parsed.id);
      added++;
    } catch (_) {
      skipped++;
    }
  }
  return _Tally(added: added, skipped: skipped);
}

/// 番組登録とは別に、エピソードごとの再生位置・再生済みフラグを取り込む。
/// 対象のエピソードが未キャッシュ（まだフィードを取得していない番組）でも、
/// 後でフィードが取得された時に[PodcastLibraryService.mergeWithSavedPlaybackState]
/// がaudioUrlで拾えるよう、キャッシュへそのまま追加しておく。
Future<_Tally> _mergePodcastEpisodes(List<dynamic> jsonList) async {
  final library = PodcastLibraryService();
  var added = 0;
  var skipped = 0;
  final byShow = <String, List<PodcastEpisode>>{};
  for (final item in jsonList) {
    if (item is! Map) continue;
    try {
      final parsed = PodcastEpisode.fromJson(Map<String, dynamic>.from(item));
      byShow.putIfAbsent(parsed.showId, () => []).add(parsed);
    } catch (_) {
      skipped++;
    }
  }

  for (final entry in byShow.entries) {
    final cached = await library.loadCachedEpisodes(entry.key);
    final byUrl = {for (final e in cached) e.audioUrl: e};
    for (final incoming in entry.value) {
      final existing = byUrl[incoming.audioUrl];
      if (existing == null) {
        byUrl[incoming.audioUrl] = incoming;
        added++;
        continue;
      }
      // 再生位置は「より進んでいる方」を採用し、後退させない。
      final incomingIsFurther =
          incoming.isPlayed ||
          incoming.playbackPosition > existing.playbackPosition;
      byUrl[incoming.audioUrl] = existing.copyWith(
        playbackPosition: incomingIsFurther
            ? incoming.playbackPosition
            : existing.playbackPosition,
        isPlayed: existing.isPlayed || incoming.isPlayed,
        isFavorite: existing.isFavorite || incoming.isFavorite,
      );
      skipped++;
    }
    await library.cacheEpisodes(entry.key, byUrl.values.toList());
  }
  return _Tally(added: added, skipped: skipped);
}
