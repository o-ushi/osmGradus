import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/services/question_prompt_auto_tag_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TopicImportParser（question-prompt-tabs.md Step 4）', () {
    test('新見出し【その他】【シチュエーション】をパースできる', () {
      final result = TopicImportParser.parseBatchImport(
        '【その他】\n1. 趣味は何ですか。\n\n【シチュエーション】\n1. 状況：遅刻連絡／条件：丁寧に',
      );
      expect(result[TopicCategory.general], ['趣味は何ですか。']);
      expect(result[TopicCategory.situational], ['状況：遅刻連絡／条件：丁寧に']);
    });

    test('旧見出し【日常】【ビジネス】は読み込み時のみgeneralへマップされる（互換1リリース分）', () {
      final result = TopicImportParser.parseBatchImport(
        '【日常】\n1. 趣味は何ですか。\n\n【ビジネス】\n1. 会議での発言は。',
      );
      expect(result[TopicCategory.general], ['趣味は何ですか。', '会議での発言は。']);
    });

    test('旧【日常】【ビジネス】は見出し単位で上限10件（合算で最大20件まで拾える）', () {
      final daily = List.generate(12, (i) => '1. これはテスト用の日常質問文その$i番です');
      final business = List.generate(12, (i) => '1. これはテスト用のビジネス質問文その$i番です');
      final text = '【日常】\n${daily.join('\n')}\n【ビジネス】\n${business.join('\n')}';

      final result = TopicImportParser.parseBatchImport(text);
      expect(result[TopicCategory.general], hasLength(20));
    });
  });

  group('AI一括取込 → 自動タグ付け（Step 4）', () {
    test('旧【日常】形式をパースしてimportTopicsすると、generalカテゴリ＋自動タグで記録される', () async {
      final parsed = TopicImportParser.parseBatchImport(
        '【日常】\n1. あなたの趣味について教えてください。',
      );
      final generalParsed = parsed[TopicCategory.general] ?? const [];
      expect(generalParsed, ['あなたの趣味について教えてください。']);

      await TopicService().importTopics(
        TopicCategory.general,
        generalParsed,
        source: QuestionPromptSource.ai,
        tagsForBody: QuestionPromptAutoTagService().suggestTags,
      );

      final service = QuestionPromptService();
      final all = await _promptsInCategory(service, TopicCategory.general);
      final added = all.singleWhere(
        (p) => p.body == 'あなたの趣味について教えてください。',
      );
      expect(added.category, TopicCategory.general);
      expect(added.tags, contains('趣味'));
    });
  });
}
