import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/question_prompt_vocab_word.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_service.dart';

Future<List<QuestionPrompt>> _promptsInCategory(
  QuestionPromptService service,
  TopicCategory category,
) async {
  final all = await service.loadAll();
  return service.filter(all, category: category);
}

ScoringResult _buildScoringResult() => ScoringResult(
  transcriptChunks: const [],
  fullTranscript: 'テストの回答です。',
  keigo: const KeigoAnalysis(categories: [], varietyScore: 0),
  complexity: const SentenceComplexityAnalysis(
    totalUnits: 1,
    complexUnitCount: 0,
    complexityRatio: 0,
  ),
  fluency: FluencyAnalysis.unavailable(allottedSeconds: 45),
  generatedAt: DateTime(2026, 1, 1),
);

PronunciationEvaluation _buildPronunciationEvaluation() =>
    PronunciationEvaluation(
      categoryEvaluations: {
        for (final category in PronunciationCategory.values)
          category: PronunciationCategoryEvaluation(
            score: 3,
            confidence: PronunciationConfidence.medium,
            evidence: '評価の根拠',
          ),
      },
      rawResponse: '{}',
      evaluationVersion: 'v2',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QuestionPromptモデル', () {
    test('categoryにrandomを渡すとassertで弾かれる', () {
      expect(
        () => QuestionPrompt.create(
          category: TopicCategory.random,
          body: '不正な分野',
          source: QuestionPromptSource.manual,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('situationalにtagsを渡すとassertで弾かれる（タブ分類はgeneral専用・Step 1）', () {
      expect(
        () => QuestionPrompt.create(
          category: TopicCategory.situational,
          body: '状況文',
          source: QuestionPromptSource.manual,
          tags: const ['趣味'],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('generalのtoJson/fromJsonでtagsが往復する（Step 1で追加したタブ分類）', () {
      final original = QuestionPrompt.create(
        category: TopicCategory.general,
        body: 'リモートワークについて',
        source: QuestionPromptSource.manual,
        tags: const ['会社', '環境'],
      );

      final restored = QuestionPrompt.fromJson(original.toJson());

      expect(restored.category, TopicCategory.general);
      expect(restored.tags, const ['会社', '環境']);
      expect(original.toJson()['category'], '一般');
      expect(original.toJson()['tags'], const ['会社', '環境']);
    });

    test('generalでtagsが空ならtoJsonにtagsキーを含めない', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.general,
        body: 'タグ未設定',
        source: QuestionPromptSource.manual,
      );
      expect(prompt.toJson().containsKey('tags'), false);
    });

    test('situationalのJSONにtagsが含まれていても読み込み時に捨てる（不正データ防御）', () {
      final legacy = QuestionPrompt.fromJson({
        'id': 'legacy-situational',
        'source': 'imported',
        'category': 'シチュエーション',
        'body': '状況文',
        'tags': ['趣味'],
      });

      expect(legacy.category, TopicCategory.situational);
      expect(legacy.tags, isEmpty);
    });

    test('tags欠落のJSONは空配列になる', () {
      final legacy = QuestionPrompt.fromJson({
        'id': 'legacy-no-tags',
        'source': 'imported',
        'category': '一般',
        'body': 'タグなしの旧データ',
      });

      expect(legacy.category, TopicCategory.general);
      expect(legacy.tags, isEmpty);
    });

    test('旧JSON "category": "日常"/"ビジネス"はgeneralに正規化される（Step 6）', () {
      final daily = QuestionPrompt.fromJson({
        'id': 'legacy-daily',
        'source': 'imported',
        'category': '日常',
        'body': '旧日常データ',
      });
      final business = QuestionPrompt.fromJson({
        'id': 'legacy-business',
        'source': 'imported',
        'category': 'ビジネス',
        'body': '旧ビジネスデータ',
      });
      // 旧英語storageKeyのJSONも同様に読める。
      final legacyEnglish = QuestionPrompt.fromJson({
        'id': 'legacy-daily-en',
        'source': 'imported',
        'category': 'daily',
        'body': '旧英語キーのデータ',
      });

      expect(daily.category, TopicCategory.general);
      expect(business.category, TopicCategory.general);
      expect(legacyEnglish.category, TopicCategory.general);
    });

    test('toJson/fromJsonで全フィールドが往復する', () {
      final original =
          QuestionPrompt.create(
            category: TopicCategory.situational,
            body: '状況文',
            source: QuestionPromptSource.imported,
            situationCondition: '条件文',
          ).copyWith(
            understood: true,
            vocabTestWords: const [
              QuestionPromptVocabWord(
                word: '調整',
                reading: 'ちょうせい',
                pos: '名詞',
                jlpt: 'N2',
                meaning: 'điều chỉnh',
                example: 'スケジュールを調整する。',
                exampleTranslation: 'Điều chỉnh lịch trình.',
              ),
            ],
            vocabTestCorrectCount: 1,
            vocabTestQuestionCount: 1,
            registeredWordIds: const ['w1', 'w2'],
            summary: '要約',
            sampleAnswer: '解答例テキスト',
            conclusion: '結論',
            reason: '理由',
            example: '具体例',
            jsstScore: 6,
            hitScore: 5,
            prepScore: 4,
            pronunciationScores: const {
              PronunciationCategory.rRow: 3,
              PronunciationCategory.sokuon: 2,
            },
            advice: 'アドバイス',
          );

      final restored = QuestionPrompt.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.source, original.source);
      expect(restored.category, original.category);
      expect(restored.body, original.body);
      expect(restored.situationCondition, original.situationCondition);
      expect(restored.understood, true);
      expect(restored.vocabTestWords, hasLength(1));
      expect(restored.vocabTestWords.single.word, '調整');
      expect(restored.vocabTestWords.single.reading, 'ちょうせい');
      expect(restored.vocabTestWords.single.meaning, 'điều chỉnh');
      expect(restored.vocabTestCorrectCount, 1);
      expect(restored.vocabTestQuestionCount, 1);
      expect(restored.isLayer1Done, true);
      expect(restored.vocabTestAccuracy, 1.0);
      expect(restored.registeredWordIds, const ['w1', 'w2']);
      expect(restored.summary, '要約');
      expect(restored.sampleAnswer, '解答例テキスト');
      expect(restored.conclusion, '結論');
      expect(restored.reason, '理由');
      expect(restored.example, '具体例');
      expect(restored.jsstScore, 6);
      expect(restored.hitScore, 5);
      expect(restored.prepScore, 4);
      expect(restored.pronunciationScores, {
        PronunciationCategory.rRow: 3,
        PronunciationCategory.sokuon: 2,
      });
      expect(restored.advice, 'アドバイス');
    });

    test('旧データ相当（新フィールドを持たないJSON）でも既定値で読める', () {
      final legacy = QuestionPrompt.fromJson({
        'id': 'legacy-1',
        'source': 'imported',
        'field': 'daily',
        'body': '旧データの本文',
      });

      expect(legacy.understood, false);
      expect(legacy.vocabTestWords, isEmpty);
      expect(legacy.vocabTestCorrectCount, isNull);
      expect(legacy.vocabTestQuestionCount, isNull);
      expect(legacy.vocabTestAccuracy, isNull);
      expect(legacy.isLayer1Done, false);
      expect(legacy.registeredWordIds, isEmpty);
      expect(legacy.summary, '');
      expect(legacy.sampleAnswer, '');
      expect(legacy.jsstScore, isNull);
      expect(legacy.hitScore, isNull);
      expect(legacy.prepScore, isNull);
      expect(legacy.pronunciationScores, isEmpty);
      expect(legacy.advice, '');
      expect(legacy.isPrepFilled, false);
      expect(legacy.hasPronunciationScore, false);
      expect(legacy.showsOverviewSummaryMarker, false);
    });

    test('旧データでunderstood==trueでも語彙テスト未実施ならisLayer1Doneはfalse（Step 1移行方針）', () {
      final legacyUnderstood = QuestionPrompt.fromJson({
        'id': 'legacy-2',
        'source': 'imported',
        'field': 'daily',
        'body': '旧データの本文',
        'understood': true,
      });

      expect(legacyUnderstood.understood, true);
      expect(legacyUnderstood.isLayer1Done, false);
      expect(legacyUnderstood.hasUserData, true);
    });

    test('isLayer1Doneは出題数・正解数が揃って初めてtrueになる。vocabTestAccuracyは正解数/出題数', () {
      final base = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '語彙テスト対象の問題文',
        source: QuestionPromptSource.manual,
      );
      expect(base.isLayer1Done, false);
      expect(base.vocabTestAccuracy, isNull);

      final onlyCount = base.copyWith(vocabTestQuestionCount: 3);
      expect(onlyCount.isLayer1Done, false);

      final zeroQuestions = base.copyWith(
        vocabTestQuestionCount: 0,
        vocabTestCorrectCount: 0,
      );
      expect(zeroQuestions.isLayer1Done, false);
      expect(zeroQuestions.vocabTestAccuracy, isNull);

      final done = base.copyWith(
        vocabTestQuestionCount: 4,
        vocabTestCorrectCount: 3,
      );
      expect(done.isLayer1Done, true);
      expect(done.vocabTestAccuracy, closeTo(0.75, 0.0001));
    });

    test('横断一覧の総評⭕️はアドバイス済またはⅠ〜Ⅴいずれか実施で立つ', () {
      final base = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '山と海どっちが好きですか？',
        source: QuestionPromptSource.manual,
      );
      expect(base.showsOverviewSummaryMarker, false);
      expect(base.hasAnyLayerDone, false);

      final withAdvice = base.copyWith(advice: '総評アドバイス');
      expect(withAdvice.showsOverviewSummaryMarker, true);

      final allDone = base.copyWith(
        vocabTestQuestionCount: 3,
        vocabTestCorrectCount: 2,
        summary: '山が好き',
        conclusion: '結論',
        reason: '理由',
        example: '例',
        jsstScore: 5,
        pronunciationScores: const {PronunciationCategory.tsu: 4},
      );
      expect(allDone.isAllLayersDone, true);
      expect(allDone.showsOverviewSummaryMarker, true);

      final onlyLayer1 = base.copyWith(
        vocabTestQuestionCount: 3,
        vocabTestCorrectCount: 2,
      );
      expect(onlyLayer1.hasAnyLayerDone, true);
      expect(onlyLayer1.showsOverviewSummaryMarker, true);

      // understoodだけ立てても（旧UI相当）isLayer1Doneにはならない。
      final onlyUnderstood = base.copyWith(understood: true);
      expect(onlyUnderstood.isLayer1Done, false);
      expect(onlyUnderstood.hasAnyLayerDone, false);

      final partial = base.copyWith(
        vocabTestQuestionCount: 3,
        vocabTestCorrectCount: 2,
        summary: '要約',
        conclusion: '結論',
        reason: '理由',
        example: '例',
      );
      expect(partial.isLayer1Done, true);
      expect(partial.isLayer2Done, true);
      expect(partial.isLayer3Done, true);
      expect(partial.isLayer4Done, false);
      expect(partial.isLayer5Done, false);
      expect(partial.showsOverviewSummaryMarker, true);
    });
  });

  group('TopicCategory.general（Step 1で追加）', () {
    test('storageKeyは一般、旧英語legacyStorageKeyはgeneral', () {
      expect(TopicCategory.general.storageKey, '一般');
      expect(TopicCategory.general.legacyStorageKey, 'general');
    });

    test('fromStorageKeyで一般からgeneralへ復元できる', () {
      expect(TopicCategoryLabel.fromStorageKey('一般'), TopicCategory.general);
    });

    test('labelKeyはstorageKeyと異なる専用キーを返す（既存のその他キーと衝突させない）', () {
      expect(TopicCategory.general.labelKey(), '問題文カテゴリ_その他');
      expect(
        TopicCategory.general.labelKey(),
        isNot(TopicCategory.general.storageKey),
      );
    });

    test('日常/ビジネス/シチュエーションのlabelKeyはstorageKeyのまま（既存挙動を維持）', () {
      expect(TopicCategory.daily.labelKey(), TopicCategory.daily.storageKey);
      expect(
        TopicCategory.business.labelKey(),
        TopicCategory.business.storageKey,
      );
      expect(
        TopicCategory.situational.labelKey(),
        TopicCategory.situational.storageKey,
      );
    });
  });

  group('QuestionPromptService.loadAll（組み込みバンクの取り込み）', () {
    test(
      '組み込み30件（日常10・ビジネス10がgeneralに統合・シチュエーション10）がsource=builtInで読める（Step 2）',
      () async {
        final all = await QuestionPromptService().loadAll();

        // Step 2から組み込みの日常/ビジネスはgeneral＋タブに統合される
        // （TopicCategory.daily/businessは25マス専用のレガシー値として残るのみで、
        // 問題文の組み込みには新規に使わない）。
        final general = all.where((p) => p.category == TopicCategory.general);
        final situational = all.where(
          (p) => p.category == TopicCategory.situational,
        );

        expect(general, hasLength(20));
        expect(situational, hasLength(10));
        expect(
          all.every((p) => p.source == QuestionPromptSource.builtIn),
          true,
        );
        expect(all.every((p) => p.understood == false), true);
        // generalの組み込みはすべて非空タグを持つ（Step 2の受け入れ条件）。
        expect(general.every((p) => p.tags.isNotEmpty), true);
        // シチュエーションはタグを持たず、状況＋条件の両方を保持する。
        expect(situational.every((p) => p.tags.isEmpty), true);
        expect(situational.every((p) => p.situationCondition != null), true);
      },
    );

    test('builtin_daily_0のtagsは趣味（マッピング表どおり）', () async {
      final all = await QuestionPromptService().loadAll();
      final prompt = all.singleWhere((p) => p.id == 'builtin_daily_0');
      expect(prompt.category, TopicCategory.general);
      expect(prompt.tags, ['趣味']);
    });

    test('組み込みビジネス問題は全問「会社」タグを持つ', () async {
      final all = await QuestionPromptService().loadAll();
      final businessOrigin = all.where(
        (p) => p.id.startsWith('builtin_business_'),
      );
      expect(businessOrigin, hasLength(10));
      expect(businessOrigin.every((p) => p.tags.contains('会社')), true);
    });

    test('2回読んでも組み込みが重複して増えない（IDでdiffするため冪等）', () async {
      final service = QuestionPromptService();
      await service.loadAll();
      final second = await service.loadAll();
      expect(
        second.where((p) => p.source == QuestionPromptSource.builtIn),
        hasLength(30),
      );
    });
  });

  group('TopicService.importTopics → QuestionPromptServiceへのミラー', () {
    test('AI取り込みはsource=aiで記録される（daily引数はgeneralへ正規化、Step 4）', () async {
      await TopicService().importTopics(TopicCategory.daily, [
        'AIが生成した問題文',
      ], source: QuestionPromptSource.ai);

      final service = QuestionPromptService();
      final general = await _promptsInCategory(service, TopicCategory.general);
      final added = general.singleWhere((p) => p.body == 'AIが生成した問題文');
      expect(added.source, QuestionPromptSource.ai);
    });

    test('手入力はsource=manualで記録される（business引数はgeneralへ正規化、Step 4）', () async {
      await TopicService().importTopics(TopicCategory.business, [
        '手入力した問題文',
      ], source: QuestionPromptSource.manual);

      final service = QuestionPromptService();
      final general = await _promptsInCategory(service, TopicCategory.general);
      final added = general.singleWhere((p) => p.body == '手入力した問題文');
      expect(added.source, QuestionPromptSource.manual);
    });

    test('sourceを渡さない場合はimportedが既定値になる（JSON/バックアップ経由との互換）', () async {
      await TopicService().importTopics(TopicCategory.situational, ['素の取り込み']);

      final service = QuestionPromptService();
      final situational = await _promptsInCategory(
        service,
        TopicCategory.situational,
      );
      final added = situational.singleWhere((p) => p.body == '素の取り込み');
      expect(added.source, QuestionPromptSource.imported);
      // 単体インポートなので状況のみで条件は持たない。
      expect(added.situationCondition, isNull);
      expect(added.tags, isEmpty);
    });

    test('同じ本文を2回取り込んでも1件のまま（重複除外）', () async {
      final topicService = TopicService();
      await topicService.importTopics(TopicCategory.daily, ['重複お題']);
      final second = await topicService.importTopics(TopicCategory.daily, ['重複お題']);

      expect(second, 0);
      final promptService = QuestionPromptService();
      final general = await _promptsInCategory(promptService, TopicCategory.general);
      expect(general.where((p) => p.body == '重複お題'), hasLength(1));
    });

    test('clearImportedで取り込み分だけ消え、組み込みは残る', () async {
      final topicService = TopicService();
      await topicService.importTopics(TopicCategory.daily, ['消される問題文']);
      await topicService.clearImported(TopicCategory.daily);

      // Step 4からTopicService.importTopics(daily/business, ...)はgeneralへ
      // 正規化されるため、取り込み・削除の確認もgeneralで行う。
      final promptService = QuestionPromptService();
      final general = await _promptsInCategory(promptService, TopicCategory.general);
      expect(general.any((p) => p.body == '消される問題文'), false);
      // 組み込みの日常/ビジネス20件（Step 2からgeneralに統合）は残る。
      expect(
        general.where((p) => p.source == QuestionPromptSource.builtIn),
        hasLength(20),
      );
    });
  });

  group('既存インストールの移行（旧topics.imported.*からの取り込み）', () {
    test('QuestionPromptService導入前に直接書かれたSharedPreferencesも読み直せる', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('topics.imported.daily', ['旧データA', '旧データB']);

      // 旧`topics.imported.daily`の生データはloadAllの移行スキャン
      // （_importableCategories）でgeneralに正規化して取り込まれる（Step 6で
      // TopicService.importTopics経由の正規化と揃えた）。
      final service = QuestionPromptService();
      final general = await _promptsInCategory(service, TopicCategory.general);

      expect(
        general
            .where((p) => p.source == QuestionPromptSource.imported)
            .map((p) => p.body),
        containsAll(['旧データA', '旧データB']),
      );
    });

    test('移行後にTopicService.loadImportedで読んでも同じ内容が見える（落ちない）', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('topics.imported.business', ['旧ビジネスお題']);

      // 新モデル側から一度読み込ませて移行を走らせる。
      await QuestionPromptService().loadAll();

      expect(await TopicService().loadImported(TopicCategory.business), [
        '旧ビジネスお題',
      ]);
    });
  });

  group('QuestionPromptService.update / delete', () {
    test('Step 1〜3時代の旧daily生データ由来（generalに正規化済み）の問題文もdeleteで'
        'topics.imported.dailyから正しく消える（Step 6）', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('topics.imported.日常', ['旧daily経由の問題文']);

      final service = QuestionPromptService();
      final all = await service.loadAll();
      final target = all.singleWhere((p) => p.body == '旧daily経由の問題文');
      expect(target.category, TopicCategory.general);

      await service.delete(target.id);

      final rawAfter = prefs.getStringList('topics.imported.日常');
      expect(rawAfter?.contains('旧daily経由の問題文') ?? false, false);

      final afterReload = await service.loadAll();
      expect(afterReload.any((p) => p.body == '旧daily経由の問題文'), false);
    });

    test('理解フラグ・要約・PREP・スコア・アドバイスを書き換えて読み直せる', () async {
      final service = QuestionPromptService();
      final all = await service.loadAll();
      final target = all.firstWhere((p) => p.category == TopicCategory.general);

      final updated = target.copyWith(
        understood: true,
        summary: '要約テキスト',
        conclusion: '結論',
        reason: '理由',
        example: '具体例',
        jsstScore: 5,
        hitScore: 4,
        prepScore: 3,
        pronunciationScores: {PronunciationCategory.tsu: 5},
        advice: 'アドバイス',
        registeredWordIds: ['vocab-1'],
      );
      await service.update(updated);

      final reloaded = await service.loadById(target.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.understood, true);
      expect(reloaded.summary, '要約テキスト');
      expect(reloaded.isPrepFilled, true);
      expect(reloaded.jsstScore, 5);
      expect(reloaded.hitScore, 4);
      expect(reloaded.prepScore, 3);
      expect(reloaded.pronunciationScores[PronunciationCategory.tsu], 5);
      expect(reloaded.hasPronunciationScore, true);
      expect(reloaded.advice, 'アドバイス');
      expect(reloaded.registeredWordIds, ['vocab-1']);
    });

    test('deleteで指定IDだけが消える', () async {
      final service = QuestionPromptService();
      await TopicService().importTopics(TopicCategory.daily, ['削除対象']);
      final before = await _promptsInCategory(service, TopicCategory.general);
      final target = before.firstWhere((p) => p.body == '削除対象');

      await service.delete(target.id);

      final after = await _promptsInCategory(service, TopicCategory.general);
      expect(after.any((p) => p.id == target.id), false);

      // 組み込みの日常/ビジネス20件はStep 2からgeneralに統合されている。
      expect(
        after.where((p) => p.source == QuestionPromptSource.builtIn),
        hasLength(20),
      );
    });

    test('deleteした取り込み本文はtopics.importedからも消え、loadAllで復活しない', () async {
      final service = QuestionPromptService();
      await TopicService().importTopics(TopicCategory.daily, ['復活させない']);
      final target = (await _promptsInCategory(
        service,
        TopicCategory.general,
      )).firstWhere((p) => p.body == '復活させない');

      await service.delete(target.id);

      // Step 4からTopicService.importTopics(daily,...)はgeneralの生リスト
      // （topics.imported.一般）へ正規化して書き込まれる。
      final imported = await TopicService().loadImported(TopicCategory.general);
      expect(imported.contains('復活させない'), false);

      final afterReload = await service.loadAll();
      expect(afterReload.any((p) => p.body == '復活させない'), false);
    });
  });

  group('filter / progressRatio', () {
    test('filterはcategory・source・layer1DoneのAND条件で絞り込む', () async {
      final service = QuestionPromptService();
      await TopicService().importTopics(TopicCategory.daily, [
        '絞り込み対象',
      ], source: QuestionPromptSource.manual);
      final all = await service.loadAll();

      final filtered = service.filter(
        all,
        category: TopicCategory.general,
        source: QuestionPromptSource.manual,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.body, '絞り込み対象');

      // layer1Done: 語彙テスト未実施のためfalseだけが残る。
      final notDone = service.filter(
        all,
        category: TopicCategory.general,
        layer1Done: false,
      );
      expect(notDone.any((p) => p.body == '絞り込み対象'), true);
      final done = service.filter(
        all,
        category: TopicCategory.general,
        layer1Done: true,
      );
      expect(done, isEmpty);
    });

    test('progressRatioは空リストで0、判定関数を満たす件数の割合を返す', () async {
      final service = QuestionPromptService();
      expect(service.progressRatio(const [], (p) => true), 0);

      final all = await service.loadAll();
      // 組み込みの日常/ビジネス20件はStep 2からgeneralに統合されている。
      final general = service.filter(all, category: TopicCategory.general);
      // 組み込み20件は全てunderstood=false。
      expect(service.progressRatio(general, (p) => p.understood), 0);

      await service.update(general.first.copyWith(understood: true));
      final reloaded = service.filter(
        await service.loadAll(),
        category: TopicCategory.general,
      );
      expect(
        service.progressRatio(reloaded, (p) => p.understood),
        closeTo(0.05, 0.0001),
      );
    });

    test(
      'filter(tag:)はgeneralのtagsに含むものだけ残し、situationalは除外する（Step 1〜2）',
      () async {
        final service = QuestionPromptService();
        final hobby = QuestionPrompt.create(
          category: TopicCategory.general,
          body: '趣味の問題文（追加分）',
          source: QuestionPromptSource.manual,
          tags: const ['趣味'],
        );
        final company = QuestionPrompt.create(
          category: TopicCategory.general,
          body: '会社の問題文（追加分）',
          source: QuestionPromptSource.manual,
          tags: const ['会社'],
        );
        final situational = QuestionPrompt.create(
          category: TopicCategory.situational,
          body: '状況文',
          source: QuestionPromptSource.manual,
          situationCondition: '条件文',
        );
        await service.importPrompts([hobby, company, situational]);
        final all = await service.loadAll();

        // 組み込みの日常にも「趣味」タグ付きが複数あるため（Step 2）、
        // 追加分を含むかどうかと、シチュエーション・無関係タグの除外だけを見る。
        final hobbyOnly = service.filter(all, tag: '趣味');
        expect(hobbyOnly.map((p) => p.body), contains('趣味の問題文（追加分）'));
        expect(
          hobbyOnly.every((p) => p.category != TopicCategory.situational),
          true,
        );
        expect(hobbyOnly.any((p) => p.body == '会社の問題文（追加分）'), false);
        expect(hobbyOnly.any((p) => p.body == '状況文'), false);

        final none = service.filter(all, tag: '存在しないタブ');
        expect(none, isEmpty);
      },
    );
  });

  group('TopicService.drawRandom（既存の抽選が壊れていないこと）', () {
    test('シチュエーションは状況と条件を返す', () async {
      final drawn = await TopicService().drawRandom(TopicCategory.situational);
      expect(drawn.text, isNotEmpty);
    });

    test('日常・ビジネス・ランダムも例外なく引ける', () async {
      for (final category in [
        TopicCategory.daily,
        TopicCategory.business,
        TopicCategory.random,
      ]) {
        final drawn = await TopicService().drawRandom(category);
        expect(drawn.text, isNotEmpty);
      }
    });
  });

  group('resyncJsstScores / resyncPronunciationScores / clearAllScores', () {
    test('resyncJsstScores: 残っている最新の結果からjsstScore等を再計算する', () async {
      final service = QuestionPromptService();
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: 'テスト問題文',
        source: QuestionPromptSource.manual,
      ).copyWith(jsstScore: 9, hitScore: 5, prepScore: 5);
      await service.importPrompts([prompt]);

      // より新しい結果（newer）を削除したあと、残っている中で最新（older）
      // から再計算する状況を模す。
      final older = SavedScoringResult(
        id: 'older',
        createdAt: DateTime(2026, 1, 1),
        result: _buildScoringResult(),
        hitStars: 2,
        prepStars: 2,
        questionPromptId: prompt.id,
        questionPromptBody: prompt.body,
      );

      await service.resyncJsstScores(prompt.id, [older]);
      var updated = await service.loadById(prompt.id);
      expect(updated!.hitScore, 2);
      expect(updated.prepScore, 2);

      // olderも削除され、対象の結果が0件になった場合はクリアする。
      await service.resyncJsstScores(prompt.id, const []);
      updated = await service.loadById(prompt.id);
      expect(updated!.jsstScore, isNull);
      expect(updated.hitScore, isNull);
      expect(updated.prepScore, isNull);
    });

    test(
      'resyncPronunciationScores: 残っている最新の評価からpronunciationScoresを再計算する',
      () async {
        final service = QuestionPromptService();
        final prompt = QuestionPrompt.create(
          category: TopicCategory.daily,
          body: 'テスト問題文2',
          source: QuestionPromptSource.manual,
        );
        await service.importPrompts([prompt]);

        final check = SavedPronunciationCheck.fromQuestionPrompt(
          id: 'check1',
          sessionId: 'sess1',
          createdAt: DateTime(2026, 1, 1),
          questionPromptId: prompt.id,
          questionPromptBody: prompt.body,
          transcript: 'テストの回答',
          evaluation: _buildPronunciationEvaluation(),
        );

        await service.resyncPronunciationScores(prompt.id, [check]);
        var updated = await service.loadById(prompt.id);
        expect(updated!.hasPronunciationScore, isTrue);
        expect(
          updated.pronunciationScores.length,
          PronunciationCategory.values.length,
        );

        // 唯一の記録が削除された場合は空にする。
        await service.resyncPronunciationScores(prompt.id, const []);
        updated = await service.loadById(prompt.id);
        expect(updated!.hasPronunciationScore, isFalse);
      },
    );

    test('clearAllScores: 全問題文のスコアをクリアし、理解等の記入内容は残す', () async {
      final service = QuestionPromptService();
      final prompt =
          QuestionPrompt.create(
            category: TopicCategory.daily,
            body: 'テスト問題文3',
            source: QuestionPromptSource.manual,
          ).copyWith(
            understood: true,
            jsstScore: 3,
            hitScore: 4,
            prepScore: 5,
            pronunciationScores: const {PronunciationCategory.rRow: 2},
          );
      await service.importPrompts([prompt]);

      await service.clearAllScores();

      final updated = await service.loadById(prompt.id);
      expect(updated!.understood, isTrue);
      expect(updated.jsstScore, isNull);
      expect(updated.hitScore, isNull);
      expect(updated.prepScore, isNull);
      expect(updated.hasPronunciationScore, isFalse);
    });
  });

  group('tag maintenance', () {
    test('renameTagOnAllPrompts は該当タグを置き換える', () async {
      final service = QuestionPromptService();
      final prompt = QuestionPrompt.create(
        category: TopicCategory.general,
        body: 'タグ置換テスト',
        source: QuestionPromptSource.manual,
        tags: const ['趣味', 'スポーツ'],
      );
      await service.importPrompts([prompt]);

      final changed = await service.renameTagOnAllPrompts('スポーツ', '音楽');
      expect(changed, 1);

      final updated = await service.loadById(prompt.id);
      expect(updated!.tags, ['趣味', '音楽']);
    });

    test('removeTagFromAllPrompts はタグを外す', () async {
      final service = QuestionPromptService();
      final prompt = QuestionPrompt.create(
        category: TopicCategory.general,
        body: 'タグ削除テスト',
        source: QuestionPromptSource.manual,
        tags: const ['趣味', 'スポーツ'],
      );
      await service.importPrompts([prompt]);

      final changed = await service.removeTagFromAllPrompts('スポーツ');
      expect(changed, 1);

      final updated = await service.loadById(prompt.id);
      expect(updated!.tags, ['趣味']);
    });
  });
}
