import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/topic_bank.dart';
import '../models/drawn_topic.dart';
import '../models/question_prompt_source.dart';
import '../models/situation_prompt.dart';
import '../models/topic_category.dart';
import 'question_prompt_service.dart';

/// osmWashabeの「サイコロでお題を引く」ロジックの移植。
/// `pool.randomElement()` 相当の単純な乱数選択で、履歴を避ける仕組みは持たない
/// （osmWashabe本体と同じ挙動）。
///
/// カテゴリ別SharedPreferencesリスト（`topics.imported.*`）は抽選・既存の
/// バックアップ/JSON入出力が引き続き依存するためStep 1でも維持するが、
/// [importTopics]・[clearImported]は[QuestionPromptService]の構造化ストアへも
/// 同じ内容をミラーする（[source]付き）。[loadImported]・[drawRandom]自体は
/// 従来どおりこのリストを直接読む。
class TopicService {
  static const _importedKeyPrefix = topicsImportedKeyPrefix;

  final _random = Random();
  final _promptService = QuestionPromptService();

  Future<List<String>> loadImported(TopicCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return loadImportedTopicsPref(prefs, category);
  }

  /// osmWashabeの `mergeTopics`（重複除外・件数上限）を移植。
  /// 戻り値は新規に追加できた件数（重複分は除く。取り込み結果メッセージの
  /// 「N件を追加しました」に使う）。[source]は問題文の入手元
  /// （AI取り込み・手入力・JSON/バックアップ経由のインポート）。既定は
  /// `imported`（呼び出し元がAI・手入力を明示しない場合の後方互換）。
  Future<int> importTopics(
    TopicCategory category,
    List<String> newTopics, {
    QuestionPromptSource source = QuestionPromptSource.imported,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadImported(category);
    final existingSet = existing.toSet();
    final additions = newTopics.where((t) => !existingSet.contains(t)).toList();
    if (additions.isEmpty) return 0;
    // 先にQuestionPromptService側へsource付きで記録してから、SharedPreferences
    // の生リストを更新する。順序を逆にすると、recordImport内のloadAll()が
    // 「まだミラーされていない生リストの新規分」を検知して先にimported扱いで
    // 取り込んでしまい、正しいsourceで記録できなくなる（Step 1回帰テストで発見）。
    await _promptService.recordImport(
      category: category,
      bodies: additions,
      source: source,
    );
    final merged = [...existing, ...additions];
    await prefs.setStringList(
      '$_importedKeyPrefix${category.storageKey}',
      merged,
    );
    return additions.length;
  }

  Future<void> clearImported(TopicCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_importedKeyPrefix${category.storageKey}');
    await prefs.remove('$_importedKeyPrefix${category.legacyStorageKey}');
    await _promptService.clearImportedCategory(category);
  }

  /// osmWashabeの「全てクリア」ボタンに相当。取り込み済みお題を全カテゴリ分削除する。
  Future<void> clearAllImported() async {
    for (final category in [
      TopicCategory.daily,
      TopicCategory.business,
      TopicCategory.situational,
    ]) {
      await clearImported(category);
    }
  }

  Future<DrawnTopic> drawRandom(TopicCategory category) async {
    if (category == TopicCategory.situational) {
      final imported = await loadImported(TopicCategory.situational);
      final pool = <SituationPrompt>[
        ...TopicBank.situationPrompts,
        ...imported.map((s) => SituationPrompt(situation: s, condition: '')),
      ];
      final picked = pool[_random.nextInt(pool.length)];
      return DrawnTopic(
        category: category,
        text: picked.situation,
        subtext: picked.condition.isEmpty ? null : picked.condition,
      );
    }

    if (category == TopicCategory.random) {
      final importedDaily = await loadImported(TopicCategory.daily);
      final importedBusiness = await loadImported(TopicCategory.business);
      final pool = [
        ...TopicBank.dailyTopics,
        ...TopicBank.businessTopics,
        ...TopicBank.supplementTopics,
        ...importedDaily,
        ...importedBusiness,
      ];
      return DrawnTopic(
        category: category,
        text: pool[_random.nextInt(pool.length)],
      );
    }

    final builtIn = category == TopicCategory.daily
        ? TopicBank.dailyTopics
        : TopicBank.businessTopics;
    final imported = await loadImported(category);
    final pool = [...builtIn, ...imported];
    return DrawnTopic(
      category: category,
      text: pool[_random.nextInt(pool.length)],
    );
  }
}

/// osmWashabeの `TopicImportParser.parseBatchImport` の移植。
/// 【見出し】区切りのテキストから、カテゴリ別のお題候補を抽出する。
class TopicImportParser {
  TopicImportParser._();

  static const int maxItemsPerSection = 10;
  static const int minTopicLength = 8;

  static const Map<TopicCategory, String> _sectionHeaders = {
    TopicCategory.daily: '日常',
    TopicCategory.business: 'ビジネス',
    TopicCategory.situational: 'シチュエーション',
  };

  static Map<TopicCategory, List<String>> parseBatchImport(String rawText) {
    final result = <TopicCategory, List<String>>{
      for (final category in _sectionHeaders.keys) category: <String>[],
    };

    TopicCategory? current;
    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matchedHeader = _matchHeader(line);
      if (matchedHeader != null) {
        current = matchedHeader;
        continue;
      }
      if (current == null) continue;
      if (result[current]!.length >= maxItemsPerSection) continue;

      final cleaned = _stripListMarker(line);
      if (cleaned.length < minTopicLength) continue;
      result[current]!.add(cleaned);
    }
    return result;
  }

  static TopicCategory? _matchHeader(String line) {
    for (final entry in _sectionHeaders.entries) {
      if (line.contains('【${entry.value}】')) return entry.key;
    }
    return null;
  }

  static String _stripListMarker(String line) {
    return line.replaceFirst(RegExp(r'^[\-\*・0-9０-９]+[.)．、\s]*'), '').trim();
  }
}
