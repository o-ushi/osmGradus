import 'package:shared_preferences/shared_preferences.dart';

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
  Future<List<QuestionPrompt>> loadAll() async {
    var stored = await _store.loadAll();
    final additions = <QuestionPrompt>[];

    final existingIds = stored.map((p) => p.id).toSet();
    for (final builtIn in _builtInPrompts()) {
      if (existingIds.add(builtIn.id)) additions.add(builtIn);
    }

    final prefs = await SharedPreferences.getInstance();
    for (final category in _importableCategories) {
      final raw = await loadImportedTopicsPref(prefs, category);
      if (raw.isEmpty) continue;
      final existingBodies = {
        for (final p in [...stored, ...additions])
          if (p.category == category && p.source != QuestionPromptSource.builtIn)
            p.body,
      };
      for (final body in raw) {
        if (!existingBodies.add(body)) continue;
        additions.add(
          QuestionPrompt.create(
            category: category,
            body: body,
            source: QuestionPromptSource.imported,
          ),
        );
      }
    }

    if (additions.isNotEmpty) {
      stored = [...stored, ...additions];
      await _store.saveAll(stored);
    }
    return stored;
  }

  Future<QuestionPrompt?> loadById(String id) async {
    final all = await loadAll();
    for (final prompt in all) {
      if (prompt.id == id) return prompt;
    }
    return null;
  }

  /// 指定したカテゴリの問題文だけを返す（組み込み＋各入手元、すべて含む）。
  Future<List<QuestionPrompt>> loadByCategory(TopicCategory category) async {
    final all = await loadAll();
    return all.where((p) => p.category == category).toList();
  }

  /// 理解・要約・PREP・スコア・アドバイス等の更新を保存する
  /// （[id]・[source]・[category]・[body]・[situationCondition]は変えない）。
  Future<void> update(QuestionPrompt prompt) async {
    final all = await loadAll();
    final updated = [
      for (final p in all)
        if (p.id == prompt.id) prompt else p,
    ];
    await _store.saveAll(updated);
  }

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
    final key = '$topicsImportedKeyPrefix${target.category.storageKey}';
    final raw = prefs.getStringList(key);
    if (raw == null || raw.isEmpty) return;
    final next = raw.where((body) => body != target.body).toList();
    if (next.length == raw.length) return;
    if (next.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, next);
    }
  }

  /// [TopicService.importTopics]から呼ばれる。新規追加分（重複除外済み）を
  /// 正しい[source]付きで構造化ストアへミラーする。
  Future<void> recordImport({
    required TopicCategory category,
    required List<String> bodies,
    required QuestionPromptSource source,
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
          QuestionPrompt.create(category: category, body: body, source: source),
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

  /// [category]・[source]・[layer1Done]のいずれかで絞り込む（未指定の軸は無視）。
  /// 一覧画面のフィルタ用途を想定した単純な同期フィルタ。[layer1Done]は
  /// [QuestionPrompt.isLayer1Done]（レイヤーⅠ語彙テスト実施済みか）で判定する。
  List<QuestionPrompt> filter(
    List<QuestionPrompt> prompts, {
    TopicCategory? category,
    QuestionPromptSource? source,
    bool? layer1Done,
  }) {
    return prompts.where((p) {
      if (category != null && p.category != category) return false;
      if (source != null && p.source != source) return false;
      if (layer1Done != null && p.isLayer1Done != layer1Done) return false;
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
  static List<QuestionPrompt> _builtInPrompts() {
    final prompts = <QuestionPrompt>[];
    for (var i = 0; i < TopicBank.dailyTopics.length; i++) {
      prompts.add(
        QuestionPrompt(
          id: 'builtin_daily_$i',
          source: QuestionPromptSource.builtIn,
          category: TopicCategory.daily,
          body: TopicBank.dailyTopics[i],
          createdAt: _builtInCreatedAt,
        ),
      );
    }
    for (var i = 0; i < TopicBank.businessTopics.length; i++) {
      prompts.add(
        QuestionPrompt(
          id: 'builtin_business_$i',
          source: QuestionPromptSource.builtIn,
          category: TopicCategory.business,
          body: TopicBank.businessTopics[i],
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
