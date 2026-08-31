import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/services/topic_json_transfer.dart';
import 'package:osm_gradus/services/topic_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TopicJsonTransfer', () {
    test('buildExportJsonは取り込み済みお題だけを含み、組み込みお題バンクは含まない', () async {
      final service = TopicService();
      // Step 4からdaily/businessはgeneralに正規化される。
      await service.importTopics(TopicCategory.daily, ['取り込んだ日常お題']);
      await service.importTopics(TopicCategory.business, ['取り込んだビジネスお題']);

      final json = await TopicJsonTransfer.buildExportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['version'], TopicJsonTransfer.formatVersion);
      final topics = (decoded['topics'] as List).cast<Map<String, dynamic>>();
      expect(topics, hasLength(2));
      expect(
        topics,
        containsAll([
          {'category': '一般', 'text': '取り込んだ日常お題'},
          {'category': '一般', 'text': '取り込んだビジネスお題'},
        ]),
      );
      // 組み込みバンク（TopicBank.dailyTopics等）の文言は含まれない。
      expect(json, isNot(contains('組み込み')));
    });

    test('itemCountはエクスポート対象カテゴリの取り込み済み件数の合計', () async {
      final service = TopicService();
      await service.importTopics(TopicCategory.daily, ['a', 'b']);
      await service.importTopics(TopicCategory.situational, ['c']);

      expect(await TopicJsonTransfer.itemCount(), 3);
    });

    test('exportしたJSONを別端末を模してimportすると同じ内容が復元される', () async {
      final service = TopicService();
      await service.importTopics(TopicCategory.daily, ['お題A', 'お題B']);
      await service.importTopics(TopicCategory.situational, ['お題C']);

      final exported = await TopicJsonTransfer.buildExportJson();

      SharedPreferences.setMockInitialValues({});

      final result = await TopicJsonTransfer.importFromContent(exported);
      expect(result.added, 3);
      expect(result.skipped, 0);

      expect(
        await service.loadImported(TopicCategory.general),
        containsAll(['お題A', 'お題B']),
      );
      expect(await service.loadImported(TopicCategory.situational), ['お題C']);
    });

    test('既に取り込み済みのお題はスキップされ、重複追加されない', () async {
      final service = TopicService();
      await service.importTopics(TopicCategory.daily, ['既存のお題']);

      final result = await TopicJsonTransfer.importFromContent(
        jsonEncode({
          'version': 1,
          'topics': [
            {'category': 'daily', 'text': '既存のお題'},
            {'category': 'daily', 'text': '新しいお題'},
          ],
        }),
      );

      expect(result.added, 1);
      expect(result.skipped, 1);
      expect(await service.loadImported(TopicCategory.general), [
        '既存のお題',
        '新しいお題',
      ]);
    });

    test('未知のカテゴリ・空文字・不正な要素は読み飛ばし、例外にしない', () async {
      final result = await TopicJsonTransfer.importFromContent(
        jsonEncode({
          'version': 1,
          'topics': [
            {'category': 'random', 'text': 'randomは取り込み専用ストアが無いため無視'},
            {'category': 'unknown', 'text': '不明カテゴリ'},
            {'category': 'daily', 'text': ''},
            {'category': 'daily'},
            'not a map',
            {'category': 'business', 'text': '有効なお題'},
          ],
        }),
      );

      expect(result.added, 1);
      expect(result.skipped, 0);
      expect(await TopicService().loadImported(TopicCategory.general), [
        '有効なお題',
      ]);
    });

    test('空文字は例外を投げる', () {
      expect(
        () => TopicJsonTransfer.importFromContent(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('壊れたJSONは例外を投げる（クラッシュではなく呼び出し側でエラー表示できる形）', () {
      expect(
        () => TopicJsonTransfer.importFromContent('{ this is not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('topicsキーが無い・配列でない場合も例外を投げる', () {
      expect(
        () => TopicJsonTransfer.importFromContent(jsonEncode({'version': 1})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TopicJsonTransfer.importFromContent(
          jsonEncode({'version': 1, 'topics': 'not a list'}),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
