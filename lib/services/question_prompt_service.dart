import 'package:shared_preferences/shared_preferences.dart';

import '../data/question_prompt_builtin_tags.dart';
import '../data/topic_bank.dart';
import '../models/question_prompt.dart';
import '../models/question_prompt_source.dart';
import '../models/saved_pronunciation_check.dart';
import '../models/saved_scoring_result.dart';
import '../models/topic_category.dart';
import 'json_list_store.dart';
import 'jsst_scoring_service.dart';

/// [QuestionPrompt]のCRUD・フィルタ・進捗集計を持つ、旧「お題」機能の
/// 後継サービス（Step 1）。
///
/// [TopicService]（サイコロ抽選・カテゴリ別SharedPreferencesリスト）はStep 1
/// 時点では引き続き並行稼働させ、[TopicService.importTopics]・
/// [TopicService.clearImported]から[recordImport]・[clearImportedCategory]を
/// 呼んで、このサービスの構造化ストアへ内容をミラーする。組み込みバンクと
/// 旧`topics.imported.*`データ（このサービス導入前の既存インストール分）は
/// [loadAll]の呼び出し時に不足分だけ自動で取り込む（差分同期）。
class QuestionPromptService {
  static const _importableCategories = [
    TopicCategory.daily,
    TopicCategory.business,
    TopicCategory.situational,
  ];

  static final _store = JsonListStore<QuestionPrompt>(
    key: 'questionPrompts.entries',
    fromJson: QuestionPrompt.fromJson,
    toJson: (prompt) => prompt.toJson(),
    idOf: (prompt) => prompt.id,
  );

  /// 組み込みバンク（[TopicBank]）・旧`topics.imported.*`データで
  /// このストアにまだ無いものを補いつつ、全件を新しい順とは逆
  /// （保存順＝組み込み→取り込み順）で返す。
  ///
  /// 既存ストアに既にある組み込み行（[QuestionPromptSource.builtIn]）は、
  /// [_builtInPrompts]（[TopicBank]・[QuestionPromptBuiltinTags]）側の
  /// category・tagsが変わっていれば追随して上書きする（Step 2で組み込みが
  /// `daily`/`business`→`general`＋タブ付きに切り替わったことに伴う移行。
  /// 学習進捗フィールドは[QuestionPrompt.copyWith]でそのまま保持する）。
  /// ただし[QuestionPrompt.contentEdited]がtrueの行（Step 5の長押し編集で
  /// ユーザーがbody/category/tagsを変更済み）は対象外とする。ここで
  /// バンク側の値に巻き戻すと、せっかくの編集が次回[loadAll]で消えてしまう。
  Future<List<QuestionPrompt>> loadAll() async {
    var stored = await _store.loadAll();
    final additions = <QuestionPrompt>[];
    final builtIns = _builtInPrompts();
    final builtInById = {for (final b in builtIns) b.id: b};

    var storeChanged = false;
    final migrated = <QuestionPrompt>[];
    for (final p in stored) {
      final builtIn = builtInById[p.id];
      if (builtIn != null &&
          p.source == QuestionPromptSource.builtIn &&
          !p.contentEdited &&
          (p.category != builtIn.category ||
              !_sameTags(p.tags, builtIn.tags))) {
        migrated.add(
          p.copyWith(category: builtIn.category, tags: builtIn.tags),
        );
        storeChanged = true;
      } else {
        migrated.add(p);
      }
    }
    stored = migrated;

    final existingIds = stored.map((p) => p.id).toSet();
    for (final builtIn in builtIns) {
      if (existingIds.add(builtIn.id)) additions.add(builtIn);
    }

    final prefs = await SharedPreferences.getInstance();
    for (final category in _importableCategories) {
      final raw = await loadImportedTopicsPref(prefs, category);
      if (raw.isEmpty) continue;
      // Step 6: このサービス導入前（daily/business時代）の生データを移行する
      // ときも、書き込みはgeneralのみに揃える（normalizeToGeneral）。生リスト
      // 自体（topics.imported.日常/ビジネス）はここでは動かさない
      // （[delete]が[_legacyRawKeysFor]で複数キーを探しに行く）。
      final normalizedCategory = normalizeToGeneral(category);
      final existingBodies = {
        for (final p in [...stored, ...additions])
          if (p.category == normalizedCategory &&
              p.source != QuestionPromptSource.builtIn)
            p.body,
      };
      for (final body in raw) {
        if (!existingBodies.add(body)) continue;
        additions.add(
          QuestionPrompt.create(
            category: normalizedCategory,
            body: body,
            source: QuestionPromptSource.imported,
          ),
        );
      }
    }

    if (additions.isNotEmpty) {
      stored = [...stored, ...additions];
    }
    if (additions.isNotEmpty || storeChanged) {
      await _store.saveAll(stored);
    }
    return stored;
  }

  /// 順序を無視したタグの一致判定（[loadAll]の組み込み行マイグレーション判定用）。
  static bool _sameTags(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  Future<QuestionPrompt?> loadById(String id) async {
    final all = await loadAll();
    for (final prompt in all) {
      if (prompt.id == id) return prompt;
    }
    return null;
  }

  /// 理解・要約・PREP・スコア・アドバイス等の更新を保存する。[prompt]は
  /// 呼び出し側が[QuestionPrompt.copyWith]で組み立てるため、body/category/tags
  /// の変更もここを通せば保存できる（[id]は変えない想定。長押し編集画面用の
  /// 専用メソッドはStep 5で追加）。
  Future<void> update(QuestionPrompt prompt) async {
    final all = await loadAll();
    final updated = [
      for (final p in all)
        if (p.id == prompt.id) prompt else p,
    ];
    await _store.saveAll(updated);
  }

  /// 長押し編集画面（`question-prompt-tabs.md` Step 5）用。[id]を固定し、
  /// body/situationCondition/category/tagsを更新する。他フィールド
  /// （進捗・スコア等）は保持する。組み込み（[QuestionPromptSource.builtIn]）
  /// 行も対象で、保存後は[QuestionPrompt.contentEdited]をtrueにして、次回
  /// [loadAll]でバンク側の値に上書きされないようにする。[id]が見つからない
  /// 場合は何もしない。[category]が[TopicCategory.situational]なら[tags]は
  /// 空に強制する（[QuestionPrompt]のassertと同じ制約）。
  ///
  /// [source]が[QuestionPromptSource.builtIn]以外で本文が`topics.imported.*`
  /// にも残っている場合、bodyが変わっていればそちらも置換する（[delete]と
  /// 同じ整合性。生リストの検索は変更前のcategoryで行う）。
  Future<void> updateContent({
    required String id,
    required String body,
    String? situationCondition,
    required TopicCategory category,
    required List<String> tags,
  }) async {
    final all = await loadAll();
    QuestionPrompt? current;
    final updatedList = <QuestionPrompt>[];
    for (final p in all) {
      if (p.id != id) {
        updatedList.add(p);
        continue;
      }
      current = p;
      updatedList.add(
        p.copyWith(
          body: body,
          situationCondition: situationCondition,
          clearSituationCondition: situationCondition == null,
          category: category,
          tags: category == TopicCategory.situational ? const [] : tags,
          contentEdited: true,
        ),
      );
    }
    if (current == null) return;
    await _store.saveAll(updatedList);

    if (current.source == QuestionPromptSource.builtIn ||
        current.body == body) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final storageKey in _rawImportKeysFor(current.category)) {
      final key = '$topicsImportedKeyPrefix$storageKey';
      final raw = prefs.getStringList(key);
      if (raw == null) continue;
      final idx = raw.indexOf(current.body);
      if (idx == -1) continue;
      final next = [...raw];
      next[idx] = body;
      await prefs.setStringList(key, next);
      return;
    }
  }

  /// [tag]を付けている[TopicCategory.general]の問題文件数。
  Future<int> countPromptsWithTag(String tag) async {
    final all = await loadAll();
    return all
        .where(
          (p) => p.category == TopicCategory.general && p.tags.contains(tag),
        )
        .length;
  }

  /// 全問題文の[oldTag]を[newTag]へ置き換える（重複は除去）。
  /// 変更した問題文の件数を返す。
  Future<int> renameTagOnAllPrompts(String oldTag, String newTag) async {
    final all = await loadAll();
    var changed = 0;
    final updated = <QuestionPrompt>[];
    for (final prompt in all) {
      if (prompt.category != TopicCategory.general ||
          !prompt.tags.contains(oldTag)) {
        updated.add(prompt);
        continue;
      }
      changed++;
      final nextTags = <String>{
        for (final tag in prompt.tags) tag == oldTag ? newTag : tag,
      }.toList();
      updated.add(prompt.copyWith(tags: nextTags, contentEdited: true));
    }
    if (changed > 0) await _store.saveAll(updated);
    return changed;
  }

  /// 全問題文から[tag]を外す。変更した問題文の件数を返す。
  Future<int> removeTagFromAllPrompts(String tag) async {
    final all = await loadAll();
    var changed = 0;
    final updated = <QuestionPrompt>[];
    for (final prompt in all) {
      if (prompt.category != TopicCategory.general ||
          !prompt.tags.contains(tag)) {
        updated.add(prompt);
        continue;
      }
      changed++;
      final nextTags = prompt.tags.where((t) => t != tag).toList();
      updated.add(prompt.copyWith(tags: nextTags, contentEdited: true));
    }
    if (changed > 0) await _store.saveAll(updated);
    return changed;
  }

  /// [delete]・[updateContent]が生リスト（`topics.imported.*`）の本文を
  /// 探すときに調べるstorageKey一覧。[TopicCategory.general]は
  /// [TopicService.importTopics]（Step 4〜）が書く`一般`キーに加え、
  /// [loadAll]の移行スキャンでgeneralに正規化された旧`daily`/`business`行の
  /// 本文がまだ残っている`日常`/`ビジネス`キーも対象にする（Step 6）。
  /// それ以外のカテゴリは自身のstorageKeyのみ。
  static List<String> _rawImportKeysFor(TopicCategory category) =>
      category == TopicCategory.general
      ? [
          TopicCategory.general.storageKey,
          TopicCategory.daily.storageKey,
          TopicCategory.business.storageKey,
        ]
      : [category.storageKey];

  Future<void> delete(String id) async {
    final all = await loadAll();
    QuestionPrompt? removed;
    final remaining = <QuestionPrompt>[];
    for (final prompt in all) {
      if (prompt.id == id) {
        removed = prompt;
      } else {
        remaining.add(prompt);
      }
    }
    await _store.saveAll(remaining);

    // 取り込み分は`topics.imported.*`にも本文が残る。消さないと次の[loadAll]で
    // 同じ本文が新しいIDで再同期されてしまい、削除が実質無効になる。
    final target = removed;
    if (target == null || target.source == QuestionPromptSource.builtIn) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final storageKey in _rawImportKeysFor(target.category)) {
      final key = '$topicsImportedKeyPrefix$storageKey';
      final raw = prefs.getStringList(key);
      if (raw == null || raw.isEmpty) continue;
      final next = raw.where((body) => body != target.body).toList();
      if (next.length == raw.length) continue;
      if (next.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(key, next);
      }
      return;
    }
  }

  /// [TopicService.importTopics]から呼ばれる。新規追加分（重複除外済み）を
  /// 正しい[source]付きで構造化ストアへミラーする。[tagsForBody]を渡すと
  /// （[category]が[TopicCategory.situational]以外のとき）本文ごとにタブを
  /// 付与する（Step 4、手入力・AI取込の自動タグ付け用。呼び出し側が
  /// [QuestionPromptAutoTagService.suggestTags]を渡す想定）。
  Future<void> recordImport({
    required TopicCategory category,
    required List<String> bodies,
    required QuestionPromptSource source,
    List<String> Function(String body)? tagsForBody,
  }) async {
    if (bodies.isEmpty) return;
    final stored = await loadAll();
    final existingBodies = {
      for (final p in stored)
        if (p.category == category && p.source != QuestionPromptSource.builtIn)
          p.body,
    };
    final additions = [
      for (final body in bodies)
        if (existingBodies.add(body))
          QuestionPrompt.create(
            category: category,
            body: body,
            source: source,
            tags: category == TopicCategory.situational
                ? const []
                : (tagsForBody?.call(body) ?? const []),
          ),
    ];
    if (additions.isEmpty) return;
    await _store.saveAll([...stored, ...additions]);
  }

  /// [GradusBackup]・[QuestionPromptJsonTransfer]から呼ばれる。IDが一致する
  /// 既存分はスキップし（ローカルの進捗を取り込み側の値で上書きしない）、
  /// 新規IDのみ追加する（[GradusBackup]の他の全マージ処理と同じ
  /// 「重複はスキップ」方針）。
  Future<QuestionPromptImportTally> importPrompts(
    List<QuestionPrompt> prompts,
  ) async {
    final stored = await loadAll();
    final ids = stored.map((p) => p.id).toSet();
    final additions = <QuestionPrompt>[];
    var skipped = 0;
    for (final prompt in prompts) {
      if (!ids.add(prompt.id)) {
        skipped++;
        continue;
      }
      additions.add(prompt);
    }
    if (additions.isNotEmpty) {
      await _store.saveAll([...stored, ...additions]);
    }
    return QuestionPromptImportTally(added: additions.length, skipped: skipped);
  }

  /// レイヤーⅣの採点結果一覧（[ScoringHistoryScreen]）で1件削除したあとに呼ぶ。
  /// [promptId]に紐づく採点結果が[remainingResults]の中にまだ残っていれば、
  /// 最新（[SavedScoringResult.createdAt]が最大）の1件から
  /// jsstScore/hitScore/prepScoreを再計算し、無ければ3項目ともクリアする
  /// （削除したのが最新の結果だった場合に、問題文一覧の実施状況が
  /// 古いまま残ってしまうのを防ぐ）。
  Future<void> resyncJsstScores(
    String promptId,
    List<SavedScoringResult> remainingResults,
  ) async {
    final current = await loadById(promptId);
    if (current == null) return;
    final forPrompt = remainingResults
        .where((r) => r.questionPromptId == promptId)
        .toList();
    if (forPrompt.isEmpty) {
      await update(
        current.copyWith(
          clearJsstScore: true,
          clearHitScore: true,
          clearPrepScore: true,
        ),
      );
      return;
    }
    forPrompt.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = forPrompt.first;
    final jsstScore = JsstScoringService.combinedReferenceLevel(latest.result);
    await update(
      current.copyWith(
        jsstScore: jsstScore,
        hitScore: latest.hitStars,
        prepScore: latest.prepStars,
        clearJsstScore: jsstScore == null,
        clearHitScore: latest.hitStars == null,
        clearPrepScore: latest.prepStars == null,
      ),
    );
  }

  /// 設定画面の「評価結果」一括リセット（[ScoringResultStorage.clearAll]・
  /// [PronunciationCheckStorage.clearAll]と対）から呼ばれる。全問題文の
  /// jsstScore/hitScore/prepScore/pronunciationScoresをクリアする
  /// （理解・要約・PREP記入・単語登録参照など、レイヤーⅠ〜Ⅲの記入内容は
  /// 対象外のためクリアしない）。
  Future<void> clearAllScores() async {
    final all = await loadAll();
    final cleared = [
      for (final p in all)
        p.copyWith(
          clearJsstScore: true,
          clearHitScore: true,
          clearPrepScore: true,
          pronunciationScores: const {},
        ),
    ];
    await _store.saveAll(cleared);
  }

  /// レイヤーⅤの発音チェック結果一覧（[PronunciationHistoryScreen]）で1件
  /// 削除したあとに呼ぶ。[promptId]に紐づく（評価解析済みの）記録が
  /// [remainingChecks]の中にまだ残っていれば、最新の1件から
  /// pronunciationScoresを再計算し、無ければ空にする（[resyncJsstScores]と同じ考え方）。
  Future<void> resyncPronunciationScores(
    String promptId,
    List<SavedPronunciationCheck> remainingChecks,
  ) async {
    final current = await loadById(promptId);
    if (current == null) return;
    final forPrompt =
        remainingChecks
            .where(
              (c) =>
                  c.source == 'questionPrompt' &&
                  c.questionPromptId == promptId &&
                  c.evaluation != null,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (forPrompt.isEmpty) {
      await update(current.copyWith(pronunciationScores: const {}));
      return;
    }
    final evaluation = forPrompt.first.evaluation!;
    await update(
      current.copyWith(
        pronunciationScores: {
          for (final entry in evaluation.categoryEvaluations.entries)
            entry.key: entry.value.score,
        },
      ),
    );
  }

  /// [TopicService.clearImported]から呼ばれる。組み込みは残し、指定した
  /// カテゴリの取り込み済み分（AI・手入力・インポートいずれも）だけを削除する。
  Future<void> clearImportedCategory(TopicCategory category) async {
    final all = await loadAll();
    final kept = all
        .where(
          (p) =>
              !(p.category == category &&
                  p.source != QuestionPromptSource.builtIn),
        )
        .toList();
    await _store.saveAll(kept);
  }

  /// [category]・[source]・[layer1Done]・[tag]のいずれかで絞り込む
  /// （未指定の軸は無視）。一覧画面のフィルタ用途を想定した単純な同期フィルタ。
  /// [layer1Done]は[QuestionPrompt.isLayer1Done]（レイヤーⅠ語彙テスト実施済みか）
  /// で判定する。[tag]指定時は[QuestionPrompt.tags]に含むものだけ残す
  /// （シチュエーションは[QuestionPrompt.tags]が常に空のため、tag指定時は
  /// 必ず除外される）。
  List<QuestionPrompt> filter(
    List<QuestionPrompt> prompts, {
    TopicCategory? category,
    QuestionPromptSource? source,
    bool? layer1Done,
    String? tag,
  }) {
    return prompts.where((p) {
      if (category != null && p.category != category) return false;
      if (source != null && p.source != source) return false;
      if (layer1Done != null && p.isLayer1Done != layer1Done) return false;
      if (tag != null && !p.tags.contains(tag)) return false;
      return true;
    }).toList();
  }

  /// [isDone]を満たす件数の割合（0.0〜1.0）。[prompts]が空なら0。
  /// レイヤーⅠ〜Ⅴ一覧の「進捗度」表示で、判定条件だけ呼び出し側が渡す
  /// （理解済み件数、要約記入済み件数、PREP全項目記入済み件数など）。
  double progressRatio(
    List<QuestionPrompt> prompts,
    bool Function(QuestionPrompt) isDone,
  ) {
    if (prompts.isEmpty) return 0;
    return prompts.where(isDone).length / prompts.length;
  }

  /// [TopicBank.supplementTopics]（「ランダム」抽選専用の補充データ）は
  /// [QuestionPrompt]化しない。[QuestionPrompt.category]はrandomを取れず、
  /// 日常/ビジネスいずれのカテゴリとも言えない雑多な内容のため、Step 1では
  /// 従来どおり[TopicService.drawRandom]内だけで使う（一覧・詳細には出ない）。
  ///
  /// [TopicBank]を[QuestionPrompt]化した仮想エントリ。IDは`builtin_<カテゴリ>_<index>`
  /// で固定し、[loadAll]が既存ストアとのdiffに使う。本文の真実のソースは
  /// [TopicBank]側であり続けるため、内容そのものは複製しても、アプリ更新で
  /// [TopicBank]が変わった場合は新しいIDの項目が追加取り込みされるだけで、
  /// 削除された項目は（ユーザーの理解フラグ等を失わないよう）ストアに残り続ける。
  ///
  /// 旧`daily`/`business`（[TopicBank.dailyTopics]/[TopicBank.businessTopics]）は
  /// Step 2から[TopicCategory.general]＋[QuestionPromptBuiltinTags]のタブで
  /// 生成する（IDの`builtin_daily_*`/`builtin_business_*`という文字列自体は
  /// 変えない。あくまで由来を示すラベルとして残す）。
  static List<QuestionPrompt> _builtInPrompts() {
    final prompts = <QuestionPrompt>[];
    for (var i = 0; i < TopicBank.dailyTopics.length; i++) {
      prompts.add(
        QuestionPrompt(
          id: 'builtin_daily_$i',
          source: QuestionPromptSource.builtIn,
          category: TopicCategory.general,
          body: TopicBank.dailyTopics[i],
          tags: QuestionPromptBuiltinTags.forDailyIndex(i),
          createdAt: _builtInCreatedAt,
        ),
      );
    }
    for (var i = 0; i < TopicBank.businessTopics.length; i++) {
      prompts.add(
        QuestionPrompt(
          id: 'builtin_business_$i',
          source: QuestionPromptSource.builtIn,
          category: TopicCategory.general,
          body: TopicBank.businessTopics[i],
          tags: QuestionPromptBuiltinTags.forBusinessIndex(i),
          createdAt: _builtInCreatedAt,
        ),
      );
    }
    for (var i = 0; i < TopicBank.situationPrompts.length; i++) {
      final situation = TopicBank.situationPrompts[i];
      prompts.add(
        QuestionPrompt(
          id: 'builtin_situational_$i',
          source: QuestionPromptSource.builtIn,
          category: TopicCategory.situational,
          body: situation.situation,
          situationCondition: situation.condition,
          createdAt: _builtInCreatedAt,
        ),
      );
    }
    return prompts;
  }

  static final _builtInCreatedAt = DateTime.utc(2024);
}

/// [QuestionPromptService.importPrompts]の結果。
class QuestionPromptImportTally {
  const QuestionPromptImportTally({required this.added, required this.skipped});

  final int added;
  final int skipped;
}
