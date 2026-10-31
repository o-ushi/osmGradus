import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/google_ai_search.dart';

void main() {
  group('GoogleAiSearch.buildLaunchPlan', () {
    test('短いプロンプトは検索クエリに載せて開く', () {
      final plan = GoogleAiSearch.buildLaunchPlan(
        prompt: '語彙を評価してください',
        lang: 'ja',
      );
      expect(plan.requiresClipboardPaste, isFalse);
      expect(plan.url.queryParameters['q'], startsWith('日本語で'));
      expect(plan.url.queryParameters['udm'], '50');
    });

    test('長すぎるプロンプトは言語接頭辞だけでAIモードを開き貼り付けを要求する', () {
      final plan = GoogleAiSearch.buildLaunchPlan(
        prompt: 'あ' * 3000,
        lang: 'ja',
      );
      expect(plan.requiresClipboardPaste, isTrue);
      expect(plan.url.queryParameters['q'], '日本語で');
      expect(plan.url.queryParameters['udm'], '50');
      expect(plan.url.queryParameters.containsKey('ie'), isFalse);
    });

    test('長い英語プロンプトの貼り付けURLも英語接頭辞を載せる', () {
      final plan = GoogleAiSearch.buildLaunchPlan(
        prompt: 'a' * 8000,
        lang: 'en',
      );
      expect(plan.requiresClipboardPaste, isTrue);
      expect(plan.url.queryParameters['q'], 'In English,');
    });
  });
}
