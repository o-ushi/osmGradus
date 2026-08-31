import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/services/dashboard_advice_storage.dart';
import 'package:osm_gradus/services/gradus_backup.dart';
import 'package:osm_gradus/services/long_article_service.dart';
import 'package:osm_gradus/services/pronunciation_exercise_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/thinking_matrix_service.dart';
import 'package:osm_gradus/services/topic_service.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('buildExportJsonが書き出したpreferencesを、importFromContentが書き戻す', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('osmGradus.language', 'en');
    await prefs.setDouble('osm_gradus.tts.speechRate', 0.6);
    await prefs.setBool('someFeature.enabled', true);
    await prefs.setInt('layer4.calibration.sampleCount', 3);
    // 「topics.imported.*」は[_explicitlyMergedPrefKeys]対象（現行storageKeyの
    // 場合はマージ処理側で、旧storageKeyの場合はTopicServiceの移行処理で扱う）
    // のため、汎用preferencesロールトリップの例には無関係なキーを使う。
    await prefs.setStringList('someFeature.list', ['お題A', 'お題B']);

    final exported = await GradusBackup.buildExportJson();

    // 別端末への復元を模して、SharedPreferencesを空にしてからインポートする。
    SharedPreferences.setMockInitialValues({});

    await GradusBackup.importFromContent(exported);

    final restored = await SharedPreferences.getInstance();
    expect(restored.getString('osmGradus.language'), 'en');
    expect(restored.getDouble('osm_gradus.tts.speechRate'), 0.6);
    expect(restored.getBool('someFeature.enabled'), true);
    expect(restored.getInt('layer4.calibration.sampleCount'), 3);
    expect(restored.getStringList('someFeature.list'), ['お題A', 'お題B']);
  });

  test('単語帳エントリのlevelを保ったままエクスポート/インポートできる', () async {
    await VocabularyService().addEntry(
      '概念',
      'khái niệm',
      reading: 'がいねん',
      level: VocabularyLevel.n1,
    );

    final exported = await GradusBackup.buildExportJson();

    // 別端末への復元を模して、SharedPreferencesを空にしてからインポートする。
    SharedPreferences.setMockInitialValues({});

    await GradusBackup.importFromContent(exported);

    final restored = await VocabularyService().loadEntries();
    expect(restored, hasLength(1));
    expect(restored.single.level, VocabularyLevel.n1);
  });

  test('単語帳エントリの例文をエクスポート/インポートできる', () async {
    await VocabularyService().addEntry(
      '概念',
      'khái niệm',
      reading: 'がいねん',
      exampleSentence: 'この概念は重要だ。',
      level: VocabularyLevel.n1,
    );

    final exported = await GradusBackup.buildExportJson();
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    final vocabulary = decoded['vocabulary'] as List<dynamic>;
    expect(vocabulary, hasLength(1));
    expect(vocabulary.single['exampleSentence'], 'この概念は重要だ。');

    SharedPreferences.setMockInitialValues({});

    await GradusBackup.importFromContent(exported);

    final restored = await VocabularyService().loadEntries();
    expect(restored, hasLength(1));
    expect(restored.single.exampleSentence, 'この概念は重要だ。');
  });

  test('インポート時、取り込み元には無いローカル限定の単語帳エントリは消えない'
      '（差分マージ結果を末尾のpreferences復元が生の値で上書きしていた回帰）', () async {
    // 別端末側の単語（インポート元にしかない語）だけを含むエクスポートを用意する。
    await VocabularyService().addEntry('B', 'b');
    final sourceExport = await GradusBackup.buildExportJson();

    // インポート先はBを含まず、ローカル限定のAだけを持つ状態にする。
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry('A', 'a');

    await GradusBackup.importFromContent(sourceExport);

    final words = (await VocabularyService().loadEntries())
        .map((e) => e.word)
        .toSet();
    expect(words, {'A', 'B'});
  });

  test('preferencesを含まないバックアップ（旧形式）でも例外を出さずインポートできる', () async {
    final legacy = jsonEncode({'version': 1, 'scoringResults': <dynamic>[]});

    await expectLater(GradusBackup.importFromContent(legacy), completes);
  });

  test('旧バックアップのquestionPrompts（"category": "日常"/"ビジネス"）もgeneralとして復元できる'
      '（question-prompt-tabs.md Step 6）', () async {
    final legacy = jsonEncode({
      'version': 5,
      'questionPrompts': [
        {
          'id': 'legacy-qp-daily',
          'source': 'manual',
          'category': '日常',
          'body': '旧バックアップの日常問題文',
          'understood': false,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        },
        {
          'id': 'legacy-qp-business',
          'source': 'manual',
          'category': 'ビジネス',
          'body': '旧バックアップのビジネス問題文',
          'understood': false,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        },
      ],
    });

    await GradusBackup.importFromContent(legacy);

    final all = await QuestionPromptService().loadAll();
    final restoredDaily = all.singleWhere((p) => p.id == 'legacy-qp-daily');
    final restoredBusiness = all.singleWhere(
      (p) => p.id == 'legacy-qp-business',
    );
    expect(restoredDaily.category, TopicCategory.general);
    expect(restoredBusiness.category, TopicCategory.general);
  });

  test('単語テスト履歴（レイヤーⅠ）をエクスポート/インポートできる', () async {
    await VocabularyCheckStorage().save(
      SavedVocabularyCheck(
        id: 'check-1',
        createdAt: DateTime(2026, 1, 1),
        sessionId: 'session-1',
        questions: const [],
      ),
    );

    final exported = await GradusBackup.buildExportJson();
    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    final restored = await VocabularyCheckStorage().loadAll();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'check-1');
    expect(restored.single.sessionId, 'session-1');
  });

  test('レイヤーⅡ〜Ⅳの取り込み済みお題をエクスポート/インポートできる', () async {
    // Step 4からdaily引数はgeneralへ正規化される。
    await TopicService().importTopics(TopicCategory.daily, ['お題A', 'お題B']);
    await TopicService().importTopics(TopicCategory.situational, ['状況A']);

    final exported = await GradusBackup.buildExportJson();
    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    expect(await TopicService().loadImported(TopicCategory.general), [
      'お題A',
      'お題B',
    ]);
    expect(await TopicService().loadImported(TopicCategory.situational), [
      '状況A',
    ]);
  });

  test('レイヤーⅤの取り込み済み読上げ文をエクスポート/インポートでき、組み込み25文は含まれない', () async {
    await PronunciationExerciseService().importExercises([
      const PronunciationExercise(
        id: 'ex-1',
        category: PronunciationCategory.tsu,
        sentence: '文A',
        reading: 'ぶんえー',
        targetExpressions: ['文A'],
        vietnameseHint: 'hint',
        evaluationPoint: 'point',
        source: PronunciationExerciseSource.imported,
      ),
    ]);

    final exported = await GradusBackup.buildExportJson();
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    expect(decoded['pronunciationExercises'], hasLength(1));

    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    final restored = await PronunciationExerciseService().loadAllImported();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'ex-1');
  });

  test('ダッシュボードの総合アドバイスをエクスポート/インポートできる', () async {
    await DashboardAdviceStorage().save('次は敬語のバリエーションを増やしましょう。');

    final exported = await GradusBackup.buildExportJson();
    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    expect(await DashboardAdviceStorage().load(), '次は敬語のバリエーションを増やしましょう。');
  });

  test('インポート先に既にアドバイスがある場合は上書きしない', () async {
    await DashboardAdviceStorage().save('元の端末のアドバイス');
    final exported = await GradusBackup.buildExportJson();

    // インポート先には別のアドバイスが既に保存されている状態を模す。
    SharedPreferences.setMockInitialValues({});
    await DashboardAdviceStorage().save('インポート先の既存アドバイス');

    await GradusBackup.importFromContent(exported);

    expect(await DashboardAdviceStorage().load(), 'インポート先の既存アドバイス');
  });

  test('レイヤーⅠの長文一覧（お気に入り・生成メタ込み）をエクスポート/インポートできる', () async {
    final added = await LongArticleService().addArticle(
      title: '旅行',
      body: '週末に旅行に行きました。',
      generationKeyword: '旅行',
      generationJlptLevel: 'n2',
      generationLength: 400,
    );
    await LongArticleService().toggleFavorite(added.single.id);

    final exported = await GradusBackup.buildExportJson();
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    final longArticles = decoded['longArticles'] as List<dynamic>;
    expect(longArticles, hasLength(1));

    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    final restored = await LongArticleService().loadArticles();
    expect(restored, hasLength(1));
    expect(restored.single.title, '旅行');
    expect(restored.single.body, '週末に旅行に行きました。');
    expect(restored.single.isFavorite, isTrue);
    expect(restored.single.generationKeyword, '旅行');
    expect(restored.single.generationJlptLevel, 'n2');
    expect(restored.single.generationLength, 400);
  });

  test('インポート時、取り込み元には無いローカル限定の長文は消えない', () async {
    await LongArticleService().addArticle(title: 'B', body: '取り込み元の長文');
    final sourceExport = await GradusBackup.buildExportJson();

    SharedPreferences.setMockInitialValues({});
    await LongArticleService().addArticle(title: 'A', body: 'ローカル限定の長文');

    await GradusBackup.importFromContent(sourceExport);

    final titles = (await LongArticleService().loadArticles())
        .map((e) => e.title)
        .toSet();
    expect(titles, {'A', 'B'});
  });

  test('レイヤーⅡ「25マス思考」のセットをキーワード込みでエクスポート/インポートできる', () async {
    final service = ThinkingMatrixService();
    final created = await service.createSet(
      title: 'セット1',
      themeNames: ['メロンパン', 'カフェのバイト', '猫', '旅行', '資格試験'],
    );
    await service.upsertCellLayer2(
      setId: created.id,
      themeId: created.themes.first.id,
      columnId: 'time',
      keyword: '海老名SAのメロンパン',
    );

    final exported = await GradusBackup.buildExportJson();
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    final sets = decoded['thinkingMatrixSets'] as List<dynamic>;
    expect(sets, hasLength(1));

    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    final restored = await ThinkingMatrixService().loadAll();
    expect(restored, hasLength(1));
    expect(restored.single.title, 'セット1');
    expect(restored.single.category, isNull);
    expect(restored.single.themes.map((t) => t.name), [
      'メロンパン',
      'カフェのバイト',
      '猫',
      '旅行',
      '資格試験',
    ]);
    final restoredCell = restored.single.cellFor(
      restored.single.themes.first.id,
      'time',
    );
    expect(restoredCell.keyword, '海老名SAのメロンパン');
    expect(restoredCell.status.name, 'filled');
  });

  test('レイヤーⅢのPREP・60秒スピーチ完了もエクスポート/インポートで往復する', () async {
    final service = ThinkingMatrixService();
    final created = await service.createFromPreset(
      TopicCategory.business,
      title: 'セット1',
    );
    await service.upsertCellLayer3(
      setId: created.id,
      themeId: created.themes.first.id,
      columnId: 'time',
      keyword: '海老名SAのメロンパン',
      conclusion: '結論です',
      reason: '理由です',
      example: '具体例です',
      speech60Done: true,
    );

    final exported = await GradusBackup.buildExportJson();
    SharedPreferences.setMockInitialValues({});
    await GradusBackup.importFromContent(exported);

    final restored = await ThinkingMatrixService().loadAll();
    final restoredCell = restored.single.cellFor(
      restored.single.themes.first.id,
      'time',
    );
    expect(restoredCell.keyword, '海老名SAのメロンパン');
    expect(restoredCell.conclusion, '結論です');
    expect(restoredCell.reason, '理由です');
    expect(restoredCell.example, '具体例です');
    expect(restoredCell.speech60Done, isTrue);
  });

  test('インポート時、取り込み元には無いローカル限定の25マスセットは消えない', () async {
    await ThinkingMatrixService().createSet(
      title: '取り込み元セット',
      themeNames: ['B1', 'B2', 'B3', 'B4', 'B5'],
    );
    final sourceExport = await GradusBackup.buildExportJson();

    SharedPreferences.setMockInitialValues({});
    await ThinkingMatrixService().createSet(
      title: 'ローカル限定セット',
      themeNames: ['A1', 'A2', 'A3', 'A4', 'A5'],
    );

    await GradusBackup.importFromContent(sourceExport);

    final titles = (await ThinkingMatrixService().loadAll())
        .map((e) => e.title)
        .toSet();
    expect(titles, {'取り込み元セット', 'ローカル限定セット'});
  });

  test('同じidの25マスセットをインポートすると内容が上書きされる（questionPromptsのスキップとは異なる仕様）', () async {
    final service = ThinkingMatrixService();
    final created = await service.createSet(
      title: '旧タイトル',
      themeNames: ['A1', 'A2', 'A3', 'A4', 'A5'],
    );
    final exported = await GradusBackup.buildExportJson();

    // 端末側だけタイトルを変えてから、古い内容のバックアップを再インポートする。
    await service.renameSet(created.id, 'ローカルで変えたタイトル');

    await GradusBackup.importFromContent(exported);

    final restored = await service.loadById(created.id);
    expect(restored!.title, '旧タイトル');
  });

  test('旧バージョン（thinkingMatrixSets節が無い）バックアップでも例外を出さずインポートできる', () async {
    final legacy = jsonEncode({'version': 5, 'scoringResults': <dynamic>[]});

    await expectLater(GradusBackup.importFromContent(legacy), completes);
    expect(await ThinkingMatrixService().loadAll(), isEmpty);
  });

  test('旧形式（netas/netaId/perspective、category・columns無し）の25マスセットを含む'
      'バックアップ全体をインポートすると、新汎用5列のオリジナルとして復元される', () async {
    final now = DateTime.now().toIso8601String();
    final legacyThemeId = 'tm_theme_legacy_1';
    final legacy = jsonEncode({
      'version': 5,
      'thinkingMatrixSets': [
        {
          'id': 'tm_legacy_backup',
          'title': '旧セット',
          'netas': [
            {'id': legacyThemeId, 'name': 'メロンパン'},
            {'id': 'tm_theme_legacy_2', 'name': 'カフェのバイト'},
            {'id': 'tm_theme_legacy_3', 'name': '猫'},
            {'id': 'tm_theme_legacy_4', 'name': '旅行'},
            {'id': 'tm_theme_legacy_5', 'name': '資格試験'},
          ],
          'cells': [
            {
              'netaId': legacyThemeId,
              'perspective': 'stance',
              'keyword': '立場のキーワード',
              'status': 'filled',
              'updatedAt': now,
            },
          ],
          'createdAt': now,
          'updatedAt': now,
        },
      ],
    });

    await GradusBackup.importFromContent(legacy);

    final restored = await ThinkingMatrixService().loadAll();
    expect(restored, hasLength(1));
    expect(restored.single.category, isNull);
    expect(restored.single.columns.map((c) => c.id), [
      'time',
      'view',
      'compare',
      'scale',
      'reason',
    ]);
    expect(restored.single.cellFor(legacyThemeId, 'view').keyword, '立場のキーワード');
  });
}
