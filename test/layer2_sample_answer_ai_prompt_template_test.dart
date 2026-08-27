import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/layer2_sample_answer_ai_prompt_template.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';

void main() {
  group('Layer2SampleAnswerAiPromptTemplate.prompt', () {
    test('問題文本文が依頼文に含まれる', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '週末はどう過ごしましたか？',
        source: QuestionPromptSource.manual,
      );

      final text = Layer2SampleAnswerAiPromptTemplate.prompt(
        prompt: prompt,
        lang: 'ja',
      );

      expect(text, contains('週末はどう過ごしましたか？'));
      expect(text, contains('45秒'));
      expect(text, contains('[質問]'));
      expect(text, contains('[日本語]'));
      expect(text, contains('[Romaji]'));
    });

    test('シチュエーションの条件文があれば問題文に続けて含める', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.situational,
        body: '状況本文',
        source: QuestionPromptSource.manual,
        situationCondition: '条件文テキスト',
      );

      final text = Layer2SampleAnswerAiPromptTemplate.prompt(
        prompt: prompt,
        lang: 'ja',
      );

      expect(text, contains('状況本文'));
      expect(text, contains('条件文テキスト'));
    });

    test('依頼文の言語を切り替えても本文は問題文をそのまま含む', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: 'テスト本文',
        source: QuestionPromptSource.manual,
      );

      final enText = Layer2SampleAnswerAiPromptTemplate.prompt(
        prompt: prompt,
        lang: 'en',
      );
      final viText = Layer2SampleAnswerAiPromptTemplate.prompt(
        prompt: prompt,
        lang: 'vi',
      );

      expect(enText, contains('テスト本文'));
      expect(enText, contains('Japanese'));
      expect(enText, contains('[質問]'));
      expect(enText, contains('[日本語]'));
      expect(enText, contains('[Romaji]'));
      expect(viText, contains('テスト本文'));
      expect(viText, contains('tiếng Nhật'));
      expect(viText, contains('[質問]'));
      expect(viText, contains('[日本語]'));
      expect(viText, contains('[Romaji]'));
    });
  });

  group('Layer2SampleAnswerAiPromptTemplate 3ブロック見出し順序', () {
    test('ja/en/viいずれも[質問]→[日本語]→[Romaji]の順で見出しを指示する', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '見出し順序確認用の問題文',
        source: QuestionPromptSource.manual,
      );

      for (final lang in ['ja', 'en', 'vi']) {
        final text = Layer2SampleAnswerAiPromptTemplate.prompt(
          prompt: prompt,
          lang: lang,
        );
        final questionIndex = text.indexOf('[質問]');
        final japaneseIndex = text.indexOf('[日本語]');
        final romajiIndex = text.indexOf('[Romaji]');

        expect(questionIndex, greaterThanOrEqualTo(0), reason: lang);
        expect(japaneseIndex, greaterThan(questionIndex), reason: lang);
        expect(romajiIndex, greaterThan(japaneseIndex), reason: lang);
      }
    });
  });

  group('Layer2SampleAnswerAiPromptTemplate.buildLaunchPlan', () {
    test('短い依頼はURLに載せて開き、模範解答がすぐ出る経路にする', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '短い問題文',
        source: QuestionPromptSource.manual,
      );

      final plan = Layer2SampleAnswerAiPromptTemplate.buildLaunchPlan(
        prompt: prompt,
        lang: 'ja',
      );

      expect(plan.prompt, contains('短い問題文'));
      expect(plan.requiresClipboardPaste, isFalse);
      expect(plan.url.host, 'www.google.co.jp');
      expect(plan.url.queryParameters['udm'], '50');
      expect(plan.url.queryParameters['q'], contains('短い問題文'));
    });
  });
}
