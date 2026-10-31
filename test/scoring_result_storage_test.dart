import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  SavedScoringResult buildResult(String id, {DateTime? createdAt}) {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    return SavedScoringResult(
      id: id,
      createdAt: createdAt ?? started,
      result: ScoringResult(
        transcriptChunks: [
          TranscriptChunk(text: 'こんにちは、元気です。', recognizedAt: started),
        ],
        fullTranscript: 'こんにちは、元気です。',
        keigo: const KeigoAnalysis(
          categories: [
            KeigoCategoryResult(
              category: 'teineigo',
              matchedExpressions: {'です'},
            ),
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

  test('save()した結果はloadAll()で新しい順に取り出せる', () async {
    final storage = ScoringResultStorage();
    await storage.save(buildResult('a'));
    await storage.save(buildResult('b'));

    final all = await storage.loadAll();
    expect(all.map((r) => r.id).toList(), ['b', 'a']);
  });

  test('保存した結果のtoJson/fromJsonは主要フィールドを往復できる', () async {
    final storage = ScoringResultStorage();
    final original = buildResult('round-trip');
    await storage.save(original);

    final all = await storage.loadAll();
    final loaded = all.single;

    expect(loaded.id, original.id);
    expect(loaded.result.fullTranscript, original.result.fullTranscript);
    expect(loaded.result.keigo.varietyScore, 1);
    expect(loaded.result.complexity.totalUnits, 1);
    expect(loaded.result.fluency.referenceLevel, 2);
    expect(loaded.result.session?.allottedSeconds, 45);
  });

  test('件数上限なく保存できる（osmWashabeの5件上限を撤廃）', () async {
    final storage = ScoringResultStorage();
    for (var i = 0; i < 12; i++) {
      await storage.save(buildResult('r$i'));
    }
    final all = await storage.loadAll();
    expect(all.length, 12);
  });

  test('delete()で指定したIDだけが削除される', () async {
    final storage = ScoringResultStorage();
    await storage.save(buildResult('a'));
    await storage.save(buildResult('b'));
    await storage.save(buildResult('c'));

    await storage.delete('b');

    final all = await storage.loadAll();
    expect(all.map((r) => r.id).toList(), ['c', 'a']);
  });

  test('update()は並び順を変えずに指定IDのレコードだけを差し替える（Step 8: PREP・的中度の後付け保存）', () async {
    final storage = ScoringResultStorage();
    await storage.save(buildResult('a'));
    await storage.save(buildResult('b'));
    await storage.save(buildResult('c'));

    final before = await storage.loadAll();
    final target = before.firstWhere((r) => r.id == 'b');
    final updated = target.withAiEvaluation(
      prepStars: 4,
      hitStars: 5,
      prepAdvice: '結論から話せています。',
      hitAdvice: '質問の的を射ています。',
    );
    await storage.update(updated);

    final after = await storage.loadAll();
    expect(after.map((r) => r.id).toList(), ['c', 'b', 'a']);
    final reloaded = after.firstWhere((r) => r.id == 'b');
    expect(reloaded.hasAiEvaluation, isTrue);
    expect(reloaded.prepStars, 4);
    expect(reloaded.hitStars, 5);
    expect(reloaded.prepAdvice, '結論から話せています。');
    expect(reloaded.hitAdvice, '質問の的を射ています。');
  });

  test('PREP・的中度・アドバイスはtoJson/fromJsonで往復する', () async {
    final storage = ScoringResultStorage();
    final original = buildResult('with-eval').withAiEvaluation(
      prepStars: 3,
      hitStars: 2,
      prepAdvice: 'PREPアドバイス',
      hitAdvice: '的中度アドバイス',
      modelAnswer: 'わたしは、そう思います。',
      modelAnswerRomaji: 'Watashi wa, sou omoimasu.',
      modelAnswerVi: 'Tôi nghĩ như vậy.',
    );
    await storage.save(original);

    final loaded = (await storage.loadAll()).single;
    expect(loaded.hasAiEvaluation, isTrue);
    expect(loaded.prepStars, 3);
    expect(loaded.hitStars, 2);
    expect(loaded.prepAdvice, 'PREPアドバイス');
    expect(loaded.hitAdvice, '的中度アドバイス');
    expect(loaded.modelAnswer, 'わたしは、そう思います。');
    expect(loaded.modelAnswerRomaji, 'Watashi wa, sou omoimasu.');
    expect(loaded.modelAnswerVi, 'Tôi nghĩ như vậy.');
  });

  test('AI評価が未送信の旧データはPREP・的中度がnullのまま壊れず読み込める', () async {
    final storage = ScoringResultStorage();
    await storage.save(buildResult('legacy'));

    final loaded = (await storage.loadAll()).single;
    expect(loaded.hasAiEvaluation, isFalse);
    expect(loaded.prepStars, isNull);
    expect(loaded.hitStars, isNull);
  });
}
