import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/long_article_comprehension_check.dart';
import 'package:osm_gradus/services/long_article_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LongArticleService.pendingReadingArticleId = null;
  });

  test('addArticle()した長文は新しい順（先頭）にloadArticles()で取り出せる', () async {
    final service = LongArticleService();
    await service.addArticle(title: '一つ目', body: '本文A');
    await service.addArticle(title: '二つ目', body: '本文B');

    final all = await service.loadArticles();
    expect(all.map((a) => a.title).toList(), ['二つ目', '一つ目']);
    expect(all.map((a) => a.sortOrder).toList(), [0, 1]);
  });

  test('生成メタ（keyword/JLPT/長さ）を保存・復元できる', () async {
    final service = LongArticleService();
    await service.addArticle(
      title: '旅行',
      body: '本文',
      generationKeyword: '旅行',
      generationJlptLevel: 'n2',
      generationLength: 400,
    );

    final saved = (await service.loadArticles()).single;
    expect(saved.generationKeyword, '旅行');
    expect(saved.generationJlptLevel, 'n2');
    expect(saved.generationLength, 400);
  });

  test('comprehensionCheckを渡すと保存・復元できる', () async {
    final service = LongArticleService();
    const check = LongArticleComprehensionCheck(
      question: '誰と旅行に行きましたか？',
      optionA: '友達',
      optionB: '家族',
      correctOption: 'A',
      explanation: '本文に「友達と一緒に」とある。',
    );
    await service.addArticle(
      title: '旅行',
      body: '本文',
      comprehensionCheck: check,
    );

    final saved = (await service.loadArticles()).single;
    expect(saved.comprehensionCheck, isNotNull);
    expect(saved.comprehensionCheck!.question, check.question);
    expect(saved.comprehensionCheck!.optionA, check.optionA);
    expect(saved.comprehensionCheck!.optionB, check.optionB);
    expect(saved.comprehensionCheck!.correctOption, check.correctOption);
    expect(saved.comprehensionCheck!.explanation, check.explanation);
  });

  test('comprehensionCheckを渡さなければnullのまま（旧データ互換）', () async {
    final service = LongArticleService();
    await service.addArticle(title: '旅行', body: '本文');

    final saved = (await service.loadArticles()).single;
    expect(saved.comprehensionCheck, isNull);
  });

  test('updateArticle()でtitle/bodyが更新され、updatedAtが進む', () async {
    final service = LongArticleService();
    final added = await service.addArticle(title: '旧題', body: '旧本文');
    final id = added.single.id;
    final originalUpdatedAt = added.single.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 2));
    await service.updateArticle(id, title: '新題', body: '新本文');

    final updated = (await service.loadArticles()).single;
    expect(updated.title, '新題');
    expect(updated.body, '新本文');
    expect(updated.updatedAt.isAfter(originalUpdatedAt), isTrue);
  });

  test('deleteArticle()で指定したIDだけが削除され、sortOrderが詰め直される', () async {
    final service = LongArticleService();
    await service.addArticle(title: 'A', body: 'a');
    final afterB = await service.addArticle(title: 'B', body: 'b');
    await service.addArticle(title: 'C', body: 'c');
    final idB = afterB.first.id;

    await service.deleteArticle(idB);

    final all = await service.loadArticles();
    expect(all.map((a) => a.title).toList(), ['C', 'A']);
    expect(all.map((a) => a.sortOrder).toList(), [0, 1]);
  });

  test('toggleFavorite()でお気に入りが反転する', () async {
    final service = LongArticleService();
    final added = await service.addArticle(title: 'A', body: 'a');
    final id = added.single.id;
    expect(added.single.isFavorite, isFalse);

    final afterToggle = await service.toggleFavorite(id);
    expect(afterToggle.single.isFavorite, isTrue);

    final afterToggleAgain = await service.toggleFavorite(id);
    expect(afterToggleAgain.single.isFavorite, isFalse);
  });

  test('reorderArticles()で指定順に並び替わり、sortOrderが振り直される', () async {
    final service = LongArticleService();
    await service.addArticle(title: 'A', body: 'a');
    await service.addArticle(title: 'B', body: 'b');
    await service.addArticle(title: 'C', body: 'c');
    final beforeReorder = await service.loadArticles();
    // 現在は新しい順で ['C', 'B', 'A']。これを ['A', 'B', 'C'] へ並び替える。
    final idsInDesiredOrder = ['A', 'B', 'C']
        .map((title) => beforeReorder.firstWhere((a) => a.title == title).id)
        .toList();

    final reordered = await service.reorderArticles(idsInDesiredOrder);

    expect(reordered.map((a) => a.title).toList(), ['A', 'B', 'C']);
    expect(reordered.map((a) => a.sortOrder).toList(), [0, 1, 2]);
  });

  test('reorderArticlesにIDを含めなかった長文は末尾に残る', () async {
    final service = LongArticleService();
    await service.addArticle(title: 'A', body: 'a');
    final afterB = await service.addArticle(title: 'B', body: 'b');
    final idB = afterB.first.id;

    final reordered = await service.reorderArticles([idB]);

    expect(reordered.map((a) => a.title).toList(), ['B', 'A']);
  });

  test('addArticle後のpickForReadingは直近保存を一度だけ優先し、次回はランダムに戻る', () async {
    final service = LongArticleService();
    await service.addArticle(title: '古い', body: 'a');
    final newer = await service.addArticle(title: '新しい', body: 'b');
    final newerId = newer.first.id;
    expect(LongArticleService.pendingReadingArticleId, newerId);

    final all = await service.loadArticles();
    final first = service.pickForReading(all, Random(0));
    expect(first?.id, newerId);
    expect(LongArticleService.pendingReadingArticleId, isNull);

    // 2回目はpendingが無いのでpickRandom（★が無ければ全体から）。
    final second = service.pickForReading(all, Random(0));
    expect(second, isNotNull);
  });
}
