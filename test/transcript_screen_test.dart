import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/export/transcript_screen.dart';

SavedScoringResult _scoringWithAiEval(String id, DateTime createdAt) {
  const text = '本日はご多忙のところお集まりいただきまして誠にありがとうございます。今後ともよろしくお願い申し上げます。';
  final result = ScoringResult(
    transcriptChunks: [TranscriptChunk(text: text, recognizedAt: createdAt)],
    fullTranscript: text,
    keigo: const KeigoAnalysis(
      varietyScore: 2,
      categories: [
        KeigoCategoryResult(category: 'teineigo', matchedExpressions: {'です'}),
        KeigoCategoryResult(category: 'sonkeigo', matchedExpressions: {'いただき'}),
        KeigoCategoryResult(category: 'kenjougo', matchedExpressions: {}),
      ],
    ),
    complexity: const SentenceComplexityAnalysis(
      totalUnits: 4,
      complexUnitCount: 2,
      complexityRatio: 0.5,
    ),
    fluency: FluencyAnalysis(
      allottedSeconds: 45,
      capturedSeconds: 40,
      timeToFirstSpeechSeconds: 1,
      estimatedSpeechSeconds: 30,
      estimatedSilenceSeconds: 10,
      silenceRatio: 0.2,
      timeUtilization: 0.7,
      spokenCharacterCount: text.length,
      charactersPerAllottedMinute: 120,
      longPauseCount: 0,
      referenceLevel: 4,
    ),
    session: SpeechSessionContext(
      allottedSeconds: 45,
      startedAt: createdAt,
      endedAt: createdAt.add(const Duration(seconds: 45)),
    ),
  );
  return SavedScoringResult(
    id: id,
    createdAt: createdAt,
    result: result,
  ).withAiEvaluation(
    prepStars: 3,
    hitStars: 4,
    prepAdvice: 'prep advice',
    hitAdvice: 'hit advice',
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('会話（JSST・的中度・PREP）が1つの表にまとまり、レイアウト崩れなく'
      '1画面に表示される', (tester) async {
    await ScoringResultStorage().save(
      _scoringWithAiEval('r1', DateTime(2026, 8, 7, 18, 59)),
    );
    await ScoringResultStorage().save(
      _scoringWithAiEval('r2', DateTime(2026, 8, 7, 21, 10)),
    );

    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    final lang = appSettings.language;
    expect(tester.takeException(), isNull);
    expect(find.text('会話'.tr(lang)), findsOneWidget);
    expect(find.text('JSST'.tr(lang)), findsOneWidget);
    expect(find.text('的中度'.tr(lang)), findsOneWidget);
    expect(find.text('PREP'.tr(lang)), findsOneWidget);
    // JSST・的中度・PREPそれぞれ独立したブロック見出しはもう出ない。
    expect(find.text('語彙'.tr(lang)), findsOneWidget);
    expect(find.text('発音'.tr(lang)), findsOneWidget);
    expect(find.text('25マス'.tr(lang)), findsOneWidget);
    expect(find.text('日常'.tr(lang)), findsOneWidget);
    expect(find.text('ビジネス'.tr(lang)), findsOneWidget);
    expect(find.text('シチュエーション'.tr(lang)), findsOneWidget);
    expect(find.text('総合判定'.tr(lang)), findsOneWidget);
    expect(find.text('テスト総合'.tr(lang)), findsOneWidget);
    expect(find.text('拡充度総合'.tr(lang)), findsOneWidget);

    // 直近2件のJSST帯・的中度・PREPが表として表示される（2件とも同じ値のため2つずつ）。
    // JSST列は見出しに既に「JSST」とあるため、値は接頭辞を外した帯だけ（折り返し防止）。
    expect(find.text('JSST 7〜'), findsNothing);
    expect(find.text('7〜'), findsNWidgets(2));
    expect(find.text('4.0'), findsNWidgets(2));
    expect(find.text('3.0'), findsNWidgets(2));
  });

  testWidgets('ベトナム語では「的中度」列見出し（Độ trúng đích）が折り返さず'
      'JSST見出しと同じ高さ（1行）に収まる', (tester) async {
    final originalLang = appSettings.language;
    appSettings.language = 'vi';
    addTearDown(() => appSettings.language = originalLang);

    await ScoringResultStorage().save(
      _scoringWithAiEval('r1', DateTime(2026, 8, 7, 18, 59)),
    );

    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final jsstHeaderHeight = tester.getSize(find.text('JSST')).height;
    final hitHeaderHeight = tester.getSize(find.text('Độ trúng đích')).height;
    // 折り返して複数行になっていれば高さがJSSTの2倍以上になるはずなので、
    // 1行分（JSSTとほぼ同じ高さ）に収まっていることを確認する。
    expect(hitHeaderHeight, lessThan(jsstHeaderHeight * 1.5));
  });

  testWidgets('英語では「的中度」列見出し（Relevance）が折り返さず'
      'JSST見出しと同じ高さ（1行）に収まる', (tester) async {
    final originalLang = appSettings.language;
    appSettings.language = 'en';
    addTearDown(() => appSettings.language = originalLang);

    await ScoringResultStorage().save(
      _scoringWithAiEval('r1', DateTime(2026, 8, 7, 18, 59)),
    );

    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final jsstHeaderHeight = tester.getSize(find.text('JSST')).height;
    final hitHeaderHeight = tester.getSize(find.text('Relevance')).height;
    expect(hitHeaderHeight, lessThan(jsstHeaderHeight * 1.5));
  });

  testWidgets('ベトナム語では総合判定・テスト総合・拡充度総合のラベルが折り返さず1行に収まる', (
    tester,
  ) async {
    final originalLang = appSettings.language;
    appSettings.language = 'vi';
    addTearDown(() => appSettings.language = originalLang);

    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Đánh giá tổng hợp')).height, lessThan(24));
    expect(
      tester.getSize(find.text('Tổng hợp bài kiểm tra')).height,
      lessThan(24),
    );
    expect(tester.getSize(find.text('Tổng hợp mở rộng')).height, lessThan(24));
    expect(tester.getSize(find.text('Tình huống')).height, lessThan(20));
  });

  testWidgets('英語では総合判定・テスト総合・拡充度総合と25マス見出しが折り返さない', (
    tester,
  ) async {
    final originalLang = appSettings.language;
    appSettings.language = 'en';
    addTearDown(() => appSettings.language = originalLang);

    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.text('Overall Assessment')).height,
      lessThan(24),
    );
    expect(tester.getSize(find.text('Test overall')).height, lessThan(24));
    expect(tester.getSize(find.text('Expansion overall')).height, lessThan(24));
    expect(tester.getSize(find.text('Situations')).height, lessThan(20));
  });

  testWidgets('判定3行のA〜Eが同じ横位置に揃い、拡充度総合は括弧付き%で、'
      '25マスは発行時点のカテゴリ%を1行で出す', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TranscriptScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final overallDx = tester
        .getTopLeft(find.byKey(const Key('transcript-grade-letter-overall')))
        .dx;
    expect(
      tester
          .getTopLeft(find.byKey(const Key('transcript-grade-letter-test')))
          .dx,
      overallDx,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('transcript-grade-letter-expansion')),
          )
          .dx,
      overallDx,
    );
    expect(find.text('（ー）'), findsOneWidget);
    expect(find.text('（0.0%）'), findsOneWidget);
    expect(find.text('0.0%'), findsNWidgets(3));
    expect(find.textContaining('25マス拡充度'), findsNothing);
  });
}
