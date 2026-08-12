import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/question_prompt_vocab_extraction_ai_prompt_template.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';

void main() {
  group('QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt', () {
    test('問題文本文と抽出ルール・最大件数・JSONスキーマを含む', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '週末はどう過ごしましたか？',
        source: QuestionPromptSource.manual,
      );

      final text = QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt(
        prompt,
      );

      expect(text, contains('週末はどう過ごしましたか？'));
      expect(text, contains('最大5つ抽出'));
      expect(text, contains('"words"'));
      expect(text, contains('"word"'));
      expect(text, contains('"exampleTranslation"'));
    });

    test('シチュエーションの条件文があれば問題文に続けて含める', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.situational,
        body: '状況本文',
        source: QuestionPromptSource.manual,
        situationCondition: '条件文テキスト',
      );

      final text = QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt(
        prompt,
      );

      expect(text, contains('状況本文'));
      expect(text, contains('条件文テキスト'));
    });

    test('アプリ表示言語がenなら訳の言語ラベルが英語になる', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: 'テスト本文',
        source: QuestionPromptSource.manual,
      );

      final enText = QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt(
        prompt,
        appLanguage: 'en',
      );
      final jaText = QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt(
        prompt,
        appLanguage: 'ja',
      );
      final viText = QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt(
        prompt,
        appLanguage: 'vi',
      );

      expect(enText, contains('英語での短い訳'));
      // 'ja'・'vi'はどちらもベトナム語訳を既定にする
      // （VocabularyEntry.translationLangの既定と同じ）。
      expect(jaText, contains('ベトナム語での短い訳'));
      expect(viText, contains('ベトナム語での短い訳'));
    });
  });

  group('QuestionPromptVocabExtractionAiPromptTemplate.buildLaunchPlan', () {
    test('プロンプト本文を含むURLかクリップボード貼り付け指示のいずれかを返す', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '短い問題文',
        source: QuestionPromptSource.manual,
      );

      final plan =
          QuestionPromptVocabExtractionAiPromptTemplate.buildLaunchPlan(
            prompt: prompt,
            appLanguage: 'ja',
          );

      expect(plan.prompt, contains('短い問題文'));
      expect(plan.url.host, 'www.google.co.jp');
    });
  });
}
