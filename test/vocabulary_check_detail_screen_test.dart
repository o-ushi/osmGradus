import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/vocab_test_session.dart';
import 'package:osm_gradus/models/vocabulary_entry.dart';
import 'package:osm_gradus/models/vocabulary_evaluation.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/layers/vocabulary_check_detail_screen.dart';

String _t(String key) => key.tr(appSettings.language);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  testWidgets('長文由来の記録に1秒チェック結果と合成正解数が出る', (tester) async {
    final check = SavedVocabularyCheck.fromSession(
      id: 'chk_1',
      sessionId: 'sess_1',
      createdAt: DateTime(2026, 8, 13),
      session: VocabTestSession(
        questions: [
          VocabTestQuestion(
            entry: VocabularyEntry(
              id: 'v1',
              word: '競い合う',
              translation: 'to compete',
              createdAt: DateTime(2026, 1, 1),
            ),
            status: VocabTestQuestionStatus.completed,
            sttResult: '競争すること',
          ),
        ],
      ),
      evaluation: const VocabularyEvaluation(
        overallScore: 5,
        questionEvaluations: [
          VocabularyQuestionEvaluation(correct: true, feedback: 'ok'),
        ],
        rawResponse: '{}',
        evaluationVersion: '1',
      ),
      longArticleId: 'la_1',
      longArticleTitle: '動物のオリンピック',
      comprehensionQuiz: const SavedComprehensionQuizResult(
        question: 'この文章の主題は何ですか？',
        optionA: '動物の競技',
        optionB: '天気予報',
        correctOption: 'A',
        selectedOption: 'A',
        isCorrect: true,
        explanationJa: '本文は動物の競技を扱っている。',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: VocabularyCheckDetailScreen(check: check)),
    );
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_見出し')), findsOneWidget);
    expect(find.text('この文章の主題は何ですか？'), findsOneWidget);
    expect(find.text('A. 動物の競技'), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_正解')), findsOneWidget);
    expect(find.text(_t('長文読解_語彙_選択').replaceFirst('%@', 'A')), findsOneWidget);
    expect(
      find.text(_t('レイヤーⅠ_語彙_正解数').replaceFirst('%1', '2').replaceFirst('%2', '2')),
      findsOneWidget,
    );
    expect(
      find.text(
        _t('長文読解_語彙_内訳')
            .replaceFirst('%1', '1')
            .replaceFirst('%2', '1')
            .replaceFirst('%3', '1')
            .replaceFirst('%4', '1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('通常の単語テスト記録には1秒チェックが出ない', (tester) async {
    final check = SavedVocabularyCheck.fromSession(
      id: 'chk_2',
      sessionId: 'sess_2',
      createdAt: DateTime(2026, 8, 13),
      session: VocabTestSession(
        questions: [
          VocabTestQuestion(
            entry: VocabularyEntry(
              id: 'v1',
              word: '観光',
              translation: 'sightseeing',
              createdAt: DateTime(2026, 1, 1),
            ),
            status: VocabTestQuestionStatus.completed,
          ),
        ],
      ),
      evaluation: const VocabularyEvaluation(
        overallScore: 4,
        questionEvaluations: [VocabularyQuestionEvaluation(correct: true)],
        rawResponse: '{}',
        evaluationVersion: '1',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: VocabularyCheckDetailScreen(check: check)),
    );
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_見出し')), findsNothing);
    expect(
      find.text(_t('レイヤーⅠ_語彙_正解数').replaceFirst('%1', '1').replaceFirst('%2', '1')),
      findsOneWidget,
    );
  });
}
