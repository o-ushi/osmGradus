import 'dart:math';

import '../models/long_article.dart';
import '../models/long_article_comprehension_check.dart';
import '../models/long_article_vocab_word.dart';
import 'json_list_store.dart';

/// 長文読解（レイヤーⅠ「長文読解」）で作成した長文の一覧をローカル保持する。
/// [VocabularyService]と同じくSharedPreferencesにJSON配列として保存するだけの
/// シンプルな構造。表示順は各[LongArticle.sortOrder]で管理し、
/// 書き込みのたびに0始まりの連番へ振り直す（保存順とsortOrderを常に一致させる）。
class LongArticleService {
  static final _store = JsonListStore<LongArticle>(
    key: 'longArticles.entries',
    fromJson: LongArticle.fromJson,
    toJson: (article) => article.toJson(),
    idOf: (article) => article.id,
  );

  /// レイヤーⅤ「長文」で、直近に保存した長文を一度だけ優先して開くためのID。
  /// [addArticle]がセットし、[pickForReading]が消費する（無い／削除済みなら
  /// [pickRandom]へフォールバック）。
  static String? pendingReadingArticleId;

  Future<List<LongArticle>> loadArticles() async {
    final articles = await _store.loadAll();
    articles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return articles;
  }

  /// 新規追加した長文を先頭（sortOrder最小）に挿入する。
  Future<List<LongArticle>> addArticle({
    required String title,
    required String body,
    bool isFavorite = false,
    String? generationKeyword,
    String? generationJlptLevel,
    int? generationLength,
    LongArticleComprehensionCheck? comprehensionCheck,
    List<LongArticleVocabWord> vocabTestWords = const [],
  }) async {
    final articles = await loadArticles();
    final now = DateTime.now();
    final article = LongArticle(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      body: body,
      createdAt: now,
      updatedAt: now,
      isFavorite: isFavorite,
      generationKeyword: generationKeyword,
      generationJlptLevel: generationJlptLevel,
      generationLength: generationLength,
      comprehensionCheck: comprehensionCheck,
      vocabTestWords: vocabTestWords,
    );
    final updated = _normalize([article, ...articles]);
    await _store.saveAll(updated);
    pendingReadingArticleId = article.id;
    return updated;
  }

  Future<List<LongArticle>> updateArticle(
    String id, {
    required String title,
    required String body,
  }) async {
    final articles = await loadArticles();
    final now = DateTime.now();
    final updated = [
      for (final article in articles)
        if (article.id == id)
          article.copyWith(title: title.trim(), body: body, updatedAt: now)
        else
          article,
    ];
    await _store.saveAll(updated);
    return updated;
  }

  /// 語彙テスト（レイヤーⅠ長文読解）の採点結果を書き戻す
  /// （[Layer1VocabScreenState._gradeLongArticle]から呼ぶ）。
  Future<List<LongArticle>> recordVocabTestResult(
    String id, {
    required int correctCount,
    required int questionCount,
    required String lastVocabularyCheckId,
  }) async {
    final articles = await loadArticles();
    final updated = [
      for (final article in articles)
        if (article.id == id)
          article.copyWith(
            vocabTestCorrectCount: correctCount,
            vocabTestQuestionCount: questionCount,
            lastVocabularyCheckId: lastVocabularyCheckId,
          )
        else
          article,
    ];
    await _store.saveAll(updated);
    return updated;
  }

  Future<List<LongArticle>> deleteArticle(String id) async {
    final articles = await loadArticles();
    final updated = _normalize(
      articles.where((article) => article.id != id).toList(),
    );
    await _store.saveAll(updated);
    return updated;
  }

  Future<List<LongArticle>> toggleFavorite(String id) async {
    final articles = await loadArticles();
    final updated = [
      for (final article in articles)
        if (article.id == id)
          article.copyWith(isFavorite: !article.isFavorite)
        else
          article,
    ];
    await _store.saveAll(updated);
    return updated;
  }

  /// [orderedIds]の順に並び替えて保存する。含まれないIDは末尾に残す。
  Future<List<LongArticle>> reorderArticles(List<String> orderedIds) async {
    final articles = await loadArticles();
    final byId = {for (final a in articles) a.id: a};
    final reordered = <LongArticle>[
      for (final id in orderedIds) ?byId.remove(id),
    ];
    reordered.addAll(byId.values);
    final updated = _normalize(reordered);
    await _store.saveAll(updated);
    return updated;
  }

  /// レイヤーⅤ「長文」音読用に1本選ぶ。
  /// [pendingReadingArticleId]があればそれを一度だけ優先し、無ければ
  /// [pickRandom]（★優先ランダム）。
  LongArticle? pickForReading(List<LongArticle> articles, [Random? random]) {
    final pendingId = pendingReadingArticleId;
    if (pendingId != null) {
      pendingReadingArticleId = null;
      for (final article in articles) {
        if (article.id == pendingId) return article;
      }
    }
    return pickRandom(articles, random);
  }

  /// レイヤーⅤ「長文」音読用に、保存済み長文から1本ランダムに選ぶ。
  /// ★（お気に入り）が1件以上あればその中から選び、無ければ全体から選ぶ
  /// （「繰り返し練習したい長文」をお気に入りで優先するための簡易な方式）。
  /// 一覧が空ならnull。
  LongArticle? pickRandom(List<LongArticle> articles, [Random? random]) {
    if (articles.isEmpty) return null;
    final favorites = articles.where((a) => a.isFavorite).toList();
    final pool = favorites.isNotEmpty ? favorites : articles;
    final rnd = random ?? Random();
    return pool[rnd.nextInt(pool.length)];
  }

  /// リストの並び順どおりにsortOrderを0始まりで振り直す。
  List<LongArticle> _normalize(List<LongArticle> articles) => [
    for (var i = 0; i < articles.length; i++)
      articles[i].copyWith(sortOrder: i),
  ];
}
