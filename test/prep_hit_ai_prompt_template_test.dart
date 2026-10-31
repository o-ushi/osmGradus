import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/google_ai_search.dart';
import 'package:osm_gradus/data/prep_hit_ai_prompt_template.dart';

void main() {
  group('PrepHitAiPromptTemplate', () {
    test('質問と回答の文字起こしを含むプロンプトを組み立てる', () {
      final prompt = PrepHitAiPromptTemplate.buildPrompt(
        questionJa: '休日は何をしますか。',
        answerTranscript: '週末は映画を見ます。',
        lang: 'ja',
      );

      expect(prompt, contains('question: 休日は何をしますか。'));
      expect(prompt, contains('answerTranscript: 週末は映画を見ます。'));
      expect(prompt, contains('prepStars'));
      expect(prompt, contains('hitStars'));
      expect(prompt, contains('modelAnswer'));
      expect(prompt, contains('やさしい言葉と短い文'));
    });

    test('英語のアドバイスは英語のまま、模範回答だけ日本語で頼む', () {
      final prompt = PrepHitAiPromptTemplate.buildPrompt(
        questionJa: '休日は何をしますか。',
        answerTranscript: '週末は映画を見ます。',
        lang: 'en',
      );

      expect(prompt, contains('modelAnswer'));
      expect(prompt, contains('natural, correct Japanese'));
      expect(prompt, contains('Both advice'));
      expect(prompt, isNot(contains('やさしい言葉と短い文')));
    });

    test('ja/en/viいずれも模範回答のローマ字とベトナム語訳を頼む', () {
      for (final lang in ['ja', 'en', 'vi']) {
        final prompt = PrepHitAiPromptTemplate.buildPrompt(
          questionJa: '休日は何をしますか。',
          answerTranscript: '週末は映画を見ます。',
          lang: lang,
        );
        expect(prompt, contains('"modelAnswerRomaji"'), reason: lang);
        expect(prompt, contains('"modelAnswerVi"'), reason: lang);
      }
    });

    test('回答の文字起こしが空/nullなら(none)になる', () {
      final prompt = PrepHitAiPromptTemplate.buildPrompt(
        questionJa: '休日は何をしますか。',
        answerTranscript: null,
        lang: 'ja',
      );

      expect(prompt, contains('answerTranscript: (none)'));
    });

    test('十分に短いプロンプトはURLプリフィル上限に収まる'
        '（クリップボード貼り付けを経由しない）', () {
      for (final lang in ['ja', 'en', 'vi']) {
        final plan = PrepHitAiPromptTemplate.buildLaunchPlan(
          questionJa: '休日は何をしますか。趣味について教えてください。',
          answerTranscript:
              '週末はよく映画を見に行きます。特にアクション映画が好きで、'
              '友達と一緒に見に行くことが多いです。それから読書もします。',
          lang: lang,
        );
        final url = GoogleAiSearch.buildUrl(
          GoogleAiSearch.withLangPrefix(plan.prompt, lang),
        );

        expect(plan.requiresClipboardPaste, isFalse, reason: 'lang=$lang');
        expect(
          url.toString().length,
          lessThanOrEqualTo(GoogleAiSearch.maxPrefillUrlLength),
          reason: 'lang=$lang',
        );
      }
    });
  });
}
