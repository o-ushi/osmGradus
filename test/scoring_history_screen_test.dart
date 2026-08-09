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
import 'package:osm_gradus/views/layers/scoring_history_screen.dart';
import 'package:osm_gradus/views/layers/scoring_result_screen.dart';

SavedScoringResult _buildResult(String id, {DateTime? createdAt}) {
  final started = DateTime(2026, 1, 1, 10, 0, 0);
  return SavedScoringResult(
    id: id,
    createdAt: createdAt ?? started,
    result: ScoringResult(
      transcriptChunks: [
        TranscriptChunk(text: 'こんにちは、今日は天気について話します。', recognizedAt: started),
      ],
      fullTranscript: 'こんにちは、今日は天気について話します。',
      keigo: const KeigoAnalysis(
        categories: [
          KeigoCategoryResult(category: 'teineigo', matchedExpressions: {'です'}),
        ],
        varietyScore: 1,
      ),
      complexity: const SentenceComplexityAnalysis(
        totalUnits: 2,
        complexUnitCount: 0,
        complexityRatio: 0,
      ),
      fluency: FluencyAnalysis(
        allottedSeconds: 45,
        capturedSeconds: 45,
        timeToFirstSpeechSeconds: 1,
        estimatedSpeechSeconds: 20,
        estimatedSilenceSeconds: 25,
        silenceRatio: 0.55,
        timeUtilization: 0.44,
        spokenCharacterCount: 20,
        charactersPerAllottedMinute: 26.6,
        longPauseCount: 0,
        referenceLevel: 4,
      ),
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('採点結果の一覧は日時・参考レベル感・抜粋だけのコンパクトな表示で、'
      'タップすると待遇表現・テキストタイプ・時間の使い方の内訳を含む詳細が開く', (tester) async {
    // 詳細画面（判定まとめ＋参考サンプル比較＋発話内容＋3軸の内訳）は縦に長く、
    // ListView(children:)の遅延レイアウトでデフォルトのテストビューポートだと
    // 下部の内訳が未マウントのままになるため、十分に大きくしておく
    // （pronunciation_check_flow_testと同じ対策）。
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ScoringResultStorage().save(_buildResult('r1'));

    await tester.pumpWidget(const MaterialApp(home: ScoringHistoryScreen()));
    await tester.pump();
    await tester.pump();

    final lang = appSettings.language;

    // 一覧はコンパクト：日時・参考レベル感バッジ・抜粋のみで、
    // 待遇表現／テキストタイプ／時間の使い方の内訳は出さない。
    expect(find.text('1/1 10:00'), findsOneWidget);
    expect(find.textContaining('こんにちは、今日は天気について話します。'), findsOneWidget);
    expect(find.text('待遇表現'.tr(lang)), findsNothing);
    expect(find.text('テキストタイプ'.tr(lang)), findsNothing);
    expect(find.text('時間の使い方'.tr(lang)), findsNothing);

    // タップすると詳細画面が開き、内訳（判定まとめカード）が確認できる。
    await tester.tap(find.byType(Dismissible));
    await tester.pumpAndSettle();

    expect(find.byType(ScoringResultScreen), findsOneWidget);
    expect(find.text('判定まとめ'.tr(lang)), findsOneWidget);
    // 「判定まとめ」の要約行と、内訳セクションの見出しの両方に現れるため
    // 複数ヒットを許容する。
    expect(find.text('待遇表現'.tr(lang)), findsWidgets);
    expect(find.text('テキストタイプ'.tr(lang)), findsWidgets);
    expect(find.text('時間の使い方'.tr(lang)), findsWidgets);

    // PREP・的中度（Step 8）は未送信のため、一覧に星は出ず、詳細には
    // 未送信の案内だけが表示される。
    expect(find.text('PREP評価・的中度'.tr(lang)), findsOneWidget);
    expect(find.text('PREP評価・的中度は未送信です。'.tr(lang)), findsOneWidget);
  });

  testWidgets('PREP・的中度のAI評価が付いた結果は、一覧に★・詳細にスコアとアドバイスが表示される', (tester) async {
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final withEvaluation = _buildResult('r2').withAiEvaluation(
      prepStars: 4,
      hitStars: 2,
      prepAdvice: '結論から話せていて良い構成です。',
      hitAdvice: '質問の意図をもう少し汲み取りましょう。',
    );
    await ScoringResultStorage().save(withEvaluation);

    await tester.pumpWidget(const MaterialApp(home: ScoringHistoryScreen()));
    await tester.pump();
    await tester.pump();

    final lang = appSettings.language;
    expect(find.textContaining('★★★★☆'), findsOneWidget);
    expect(find.textContaining('★★☆☆☆'), findsOneWidget);

    await tester.tap(find.byType(Dismissible));
    await tester.pumpAndSettle();

    expect(find.text('結論から話せていて良い構成です。'), findsOneWidget);
    expect(find.text('質問の意図をもう少し汲み取りましょう。'), findsOneWidget);
    expect(find.text('PREP評価・的中度は未送信です。'.tr(lang)), findsNothing);
  });
}
