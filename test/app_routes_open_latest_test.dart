import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/navigation/app_routes.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/views/layers/pronunciation_check_detail_screen.dart';
import 'package:osm_gradus/views/layers/scoring_result_screen.dart';
import 'package:osm_gradus/views/layers/vocabulary_check_detail_screen.dart';

SavedScoringResult _buildScoringResult(String id) {
  final started = DateTime(2026, 1, 1, 10, 0, 0);
  return SavedScoringResult(
    id: id,
    createdAt: started,
    result: ScoringResult(
      transcriptChunks: [
        TranscriptChunk(text: 'わたしはこう考えます。', recognizedAt: started),
      ],
      fullTranscript: 'わたしはこう考えます。',
      keigo: const KeigoAnalysis(
        categories: [
          KeigoCategoryResult(category: 'teineigo', matchedExpressions: {'です'}),
        ],
        varietyScore: 1,
      ),
      complexity: const SentenceComplexityAnalysis(
        totalUnits: 1,
        complexUnitCount: 0,
        complexityRatio: 0,
      ),
      fluency: FluencyAnalysis(
        allottedSeconds: 45,
        capturedSeconds: 45,
        timeToFirstSpeechSeconds: 1,
        estimatedSpeechSeconds: 10,
        estimatedSilenceSeconds: 35,
        silenceRatio: 0.78,
        timeUtilization: 0.22,
        spokenCharacterCount: 11,
        charactersPerAllottedMinute: 14.6,
        longPauseCount: 1,
        referenceLevel: 2,
      ),
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    ),
  );
}

/// テスト対象の[AppRoutes.openLatest*]ヘルパを呼ぶだけの最小ホーム画面。
class _OpenLatestHome extends StatelessWidget {
  const _OpenLatestHome({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  Future<void> Function(BuildContext context) onOpen,
) => tester.pumpWidget(MaterialApp(home: _OpenLatestHome(onOpen: onOpen)));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppRoutes.openLatestScoringResult（Step 6）', () {
    testWidgets('結果が1件あるとき、その詳細画面がpushされる', (tester) async {
      final saved = _buildScoringResult('r1');
      await ScoringResultStorage().save(saved);

      await _pumpHome(tester, AppRoutes.openLatestScoringResult);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ScoringResultScreen>(
        find.byType(ScoringResultScreen),
      );
      expect(screen.result.id, 'r1');
    });

    testWidgets('結果が0件のときは何もせず落ちない', (tester) async {
      await _pumpHome(tester, AppRoutes.openLatestScoringResult);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ScoringResultScreen), findsNothing);
    });
  });

  group('AppRoutes.openLatestPronunciationCheck（Step 6）', () {
    testWidgets('結果が1件あるとき、その詳細画面がpushされる', (tester) async {
      final saved = SavedPronunciationCheck(
        id: 'p1',
        createdAt: DateTime(2026, 1, 1),
        transcript: 'てすとです。',
      );
      await PronunciationCheckStorage().save(saved);

      await _pumpHome(tester, AppRoutes.openLatestPronunciationCheck);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final screen = tester.widget<PronunciationCheckDetailScreen>(
        find.byType(PronunciationCheckDetailScreen),
      );
      expect(screen.check.id, 'p1');
    });

    testWidgets('結果が0件のときは何もせず落ちない', (tester) async {
      await _pumpHome(tester, AppRoutes.openLatestPronunciationCheck);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PronunciationCheckDetailScreen), findsNothing);
    });
  });

  group('AppRoutes.openLatestVocabularyCheck（Step 6）', () {
    testWidgets('結果が1件あるとき、その詳細画面がpushされる', (tester) async {
      final saved = SavedVocabularyCheck(
        id: 'v1',
        createdAt: DateTime(2026, 1, 1),
        sessionId: 's1',
        questions: const [],
      );
      await VocabularyCheckStorage().save(saved);

      await _pumpHome(tester, AppRoutes.openLatestVocabularyCheck);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final screen = tester.widget<VocabularyCheckDetailScreen>(
        find.byType(VocabularyCheckDetailScreen),
      );
      expect(screen.check.id, 'v1');
    });

    testWidgets('結果が0件のときは何もせず落ちない', (tester) async {
      await _pumpHome(tester, AppRoutes.openLatestVocabularyCheck);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VocabularyCheckDetailScreen), findsNothing);
    });
  });
}
