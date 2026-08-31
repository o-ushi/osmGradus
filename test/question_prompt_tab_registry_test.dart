import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/services/question_prompt_tab_registry.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QuestionPromptTabRegistry', () {
    test('組み込み6タブがこの順で返る（独自タブを1件も追加していない状態）', () async {
      final tabs = await QuestionPromptTabRegistry().allTabKeys();
      expect(tabs, const ['趣味', '健康', '旅行', '家族', '環境', '会社']);
    });

    test('独自タブを追加すると組み込みの後ろに付く', () async {
      final registry = QuestionPromptTabRegistry();
      await registry.addCustomTab('スポーツ');

      final tabs = await registry.allTabKeys();
      expect(tabs, const ['趣味', '健康', '旅行', '家族', '環境', '会社', 'スポーツ']);
    });

    test('前後の空白はトリムして保存する', () async {
      final registry = QuestionPromptTabRegistry();
      await registry.addCustomTab('  スポーツ  ');

      final tabs = await registry.allTabKeys();
      expect(tabs.contains('スポーツ'), true);
      expect(tabs.contains('  スポーツ  '), false);
    });

    test('空文字は無視する', () async {
      final registry = QuestionPromptTabRegistry();
      await registry.addCustomTab('   ');

      final tabs = await registry.allTabKeys();
      expect(tabs, const ['趣味', '健康', '旅行', '家族', '環境', '会社']);
    });

    test('組み込みと同名は追加しない（重複除外）', () async {
      final registry = QuestionPromptTabRegistry();
      await registry.addCustomTab('趣味');

      final tabs = await registry.allTabKeys();
      expect(tabs, const ['趣味', '健康', '旅行', '家族', '環境', '会社']);
    });

    test('既存の独自タブと同名も追加しない（重複除外）', () async {
      final registry = QuestionPromptTabRegistry();
      await registry.addCustomTab('スポーツ');
      await registry.addCustomTab('スポーツ');

      final tabs = await registry.allTabKeys();
      expect(tabs.where((t) => t == 'スポーツ'), hasLength(1));
    });

    test('最大長を超えるタブ名は無視する', () async {
      final registry = QuestionPromptTabRegistry();
      final tooLong = 'あ' * (QuestionPromptTabRegistry.maxTabNameLength + 1);
      await registry.addCustomTab(tooLong);

      final tabs = await registry.allTabKeys();
      expect(tabs.contains(tooLong), false);
    });
  });
}
