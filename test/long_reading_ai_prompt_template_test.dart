import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/google_ai_search.dart';
import 'package:osm_gradus/data/long_reading_ai_prompt_template.dart';
import 'package:osm_gradus/models/long_article.dart';

LongArticle _article(String body) => LongArticle(
  id: 'x',
  title: 'タイトル',
  body: body,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('LongReadingAiPromptTemplate', () {
    test('本文は冒頭maxArticleExcerptChars文字、文字起こしはmaxTranscriptChars文字に'
        '切り詰める', () {
      final prompt = LongReadingAiPromptTemplate.evaluationPrompt(
        article: _article('あ' * 500),
        transcript: 'い' * 500,
        lang: 'ja',
      );

      expect(
        prompt,
        contains('あ' * LongReadingAiPromptTemplate.maxArticleExcerptChars),
      );
      expect(prompt, isNot(contains('あ' * 300)));
      expect(
        prompt,
        contains('い' * LongReadingAiPromptTemplate.maxTranscriptChars),
      );
      expect(prompt, isNot(contains('い' * 200)));
    });

    test('長文1000字＋3分の録音相当の長い文字起こしでもURLプリフィル上限に収まる'
        '（クリップボード貼り付けを経由しない）', () {
      for (final lang in ['ja', 'en', 'vi']) {
        final plan = LongReadingAiPromptTemplate.buildLaunchPlan(
          article: _article('友達と一緒に旅行に行きました。とても楽しかったです。' * 40),
          transcript: 'ともだちといっしょにりょこうにいきました。とてもたのしかったです。' * 30,
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

    test('本文・文字起こしが空でもクラッシュせず(none)を出力する', () {
      final prompt = LongReadingAiPromptTemplate.evaluationPrompt(
        article: _article(''),
        transcript: '',
        lang: 'ja',
      );

      expect(prompt, contains('(none)'));
    });
  });
}
