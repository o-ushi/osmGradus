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

  /// [normalizeToGeneral]のエイリアス（Step 4時点からの既存呼び出し元との
  /// 互換のため名前を維持）。
  static TopicCategory normalizeCategory(TopicCategory category) =>
      normalizeToGeneral(category);

  /// osmWashabeの `mergeTopics`（重複除外・件数上限）を移植。
  /// 戻り値は新規に追加できた件数（重複分は除く。取り込み結果メッセージの
  /// 「N件を追加しました」に使う）。[source]は問題文の入手元
  /// （AI取り込み・手入力・JSON/バックアップ経由のインポート）。既定は
  /// `imported`（呼び出し元がAI・手入力を明示しない場合の後方互換）。
  /// [category]は[normalizeCategory]で正規化してから使う（[daily]/[business]
  /// を渡しても`general`として記録・保存される）。[tagsForBody]はStep 4の
  /// 自動タグ付け用（[QuestionPromptService.recordImport]参照）。
  Future<int> importTopics(
    TopicCategory category,
    List<String> newTopics, {
    QuestionPromptSource source = QuestionPromptSource.imported,
    List<String> Function(String body)? tagsForBody,
  }) async {
    final normalizedCategory = normalizeCategory(category);
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadImported(normalizedCategory);
    final existingSet = existing.toSet();
    final additions = newTopics.where((t) => !existingSet.contains(t)).toList();
    if (additions.isEmpty) return 0;
    // 先にQuestionPromptService側へsource付きで記録してから、SharedPreferences
    // の生リストを更新する。順序を逆にすると、recordImport内のloadAll()が
    // 「まだミラーされていない生リストの新規分」を検知して先にimported扱いで
    // 取り込んでしまい、正しいsourceで記録できなくなる（Step 1回帰テストで発見）。
    await _promptService.recordImport(
      category: normalizedCategory,
      bodies: additions,
      source: source,
      tagsForBody: tagsForBody,
    );
    final merged = [...existing, ...additions];
    await prefs.setStringList(
      '$_importedKeyPrefix${normalizedCategory.storageKey}',
      merged,
    );
    return additions.length;
  }

  /// [category]の生リスト（`topics.imported.*`）を削除する。[category]は
  /// 正規化せずそのまま使う（旧`daily`/`business`のインストール済みデータも
  /// 掃除できるようにするため）。[QuestionPromptService]側は
  /// [normalizeCategory]した値で削除する（Step 4以降、そちらは`general`
  /// でしか記録されないため）。
  Future<void> clearImported(TopicCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_importedKeyPrefix${category.storageKey}');
    await prefs.remove('$_importedKeyPrefix${category.legacyStorageKey}');
    await _promptService.clearImportedCategory(normalizeCategory(category));
  }

  /// osmWashabeの「全てクリア」ボタンに相当。取り込み済みお題を全カテゴリ分削除する。
  /// [daily]/[business]は Step 4以前のインストールで残っている可能性がある
  /// 生リストを掃除するために含める（[general]と合わせて4カテゴリ分）。
  Future<void> clearAllImported() async {
    for (final category in [
      TopicCategory.daily,
      TopicCategory.business,
      TopicCategory.general,
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

    if (category == TopicCategory.general) {
      // Step 3から練習レイヤー（レイヤーⅢ・Ⅳ）の分野セレクタは「その他」＝
      // generalのみを選ぶため、旧daily/businessの2プールを合算して引く
      // （組み込み問題文自体はStep 2でgeneralに統合済みだが、こちらの
      // TopicService側の抽選プール・取り込み済みリストはStep 1〜3では
      // 依然daily/business別のまま。日常/ビジネスの区別をやめた新カテゴリ
      // という設計を反映し、ここで合算する）。
      final importedDaily = await loadImported(TopicCategory.daily);
      final importedBusiness = await loadImported(TopicCategory.business);
      final pool = [
        ...TopicBank.dailyTopics,
        ...TopicBank.businessTopics,
        ...importedDaily,
        ...importedBusiness,
      ];
      return DrawnTopic(
        category: category,
        text: pool[_random.nextInt(pool.length)],
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
///
/// Step 4（`question-prompt-tabs.md`）から新プロンプトの見出しは
/// 【その他】／【シチュエーション】の2つ。旧見出し【日常】【ビジネス】は
/// 読み込み時のみ`general`にマップする互換対応（新規のプロンプト出力では
/// もう使わない）。見出しごとの上限（[maxItemsPerSection]）は見出し文字列
/// 単位で数える（旧【日常】【ビジネス】は別見出しとして扱うため、両方
/// 貼り付けられた旧形式のテキストからは合計で最大20件まで拾える）。
class TopicImportParser {
  TopicImportParser._();

  static const int maxItemsPerSection = 10;
  static const int minTopicLength = 8;

  static const Map<String, TopicCategory> _headerCategories = {
    'その他': TopicCategory.general,
    '日常': TopicCategory.general,
    'ビジネス': TopicCategory.general,
    'シチュエーション': TopicCategory.situational,
  };

  static Map<TopicCategory, List<String>> parseBatchImport(String rawText) {
    final result = <TopicCategory, List<String>>{
      TopicCategory.general: <String>[],
      TopicCategory.situational: <String>[],
    };
    final sectionCounts = <String, int>{};

    String? currentHeader;
    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matchedHeader = _matchHeader(line);
      if (matchedHeader != null) {
        currentHeader = matchedHeader;
        continue;
      }
      if (currentHeader == null) continue;
      final count = sectionCounts[currentHeader] ?? 0;
      if (count >= maxItemsPerSection) continue;

      final cleaned = _stripListMarker(line);
      if (cleaned.length < minTopicLength) continue;
      result[_headerCategories[currentHeader]]!.add(cleaned);
      sectionCounts[currentHeader] = count + 1;
    }
    return result;
  }

  static String? _matchHeader(String line) {
    for (final header in _headerCategories.keys) {
      if (line.contains('【$header】')) return header;
    }
    return null;
  }

  static String _stripListMarker(String line) {
    return line.replaceFirst(RegExp(r'^[\-\*・0-9０-９]+[.)．、\s]*'), '').trim();
  }
}
