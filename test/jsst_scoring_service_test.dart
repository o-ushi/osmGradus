import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/services/jsst_scoring_service.dart';

void main() {
  test('丁寧語（です/ます）を含む発話は待遇表現のvarietyScoreに反映される', () {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    final chunks = [
      TranscriptChunk(text: '今日は天気がいいです。', recognizedAt: started),
    ];
    final result = JsstScoringService.score(
      chunks,
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    );

    expect(result.keigo.varietyScore, greaterThanOrEqualTo(1));
    final teineigo = result.keigo.categories.firstWhere(
      (c) => c.category == 'teineigo',
    );
    expect(teineigo.matchedExpressions, isNotEmpty);
  });

  test('従属節接続表現（ので/から等）を含む発話は複文としてカウントされる', () {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    final chunks = [
      TranscriptChunk(text: '雨が降っていたので、傘を持って行きました。', recognizedAt: started),
    ];
    final result = JsstScoringService.score(chunks);

    expect(result.complexity.totalUnits, 1);
    expect(result.complexity.complexUnitCount, 1);
    expect(result.complexity.complexityRatio, 1.0);
  });

  test('接続表現を含まない単純な発話は複文としてカウントされない', () {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    final chunks = [TranscriptChunk(text: '猫が好きです。', recognizedAt: started)];
    final result = JsstScoringService.score(chunks);

    expect(result.complexity.complexUnitCount, 0);
    expect(result.complexity.complexityRatio, 0.0);
  });

  test('セッション時間が分かれば流暢さ（時間の使い方）が算出される', () {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    final chunks = [
      TranscriptChunk(
        text: '私は毎日日本語を勉強しています。とても楽しいです。',
        recognizedAt: started.add(const Duration(seconds: 2)),
      ),
    ];
    final result = JsstScoringService.score(
      chunks,
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    );

    expect(result.fluency.capturedSeconds, 45.0);
    expect(result.fluency.spokenCharacterCount, chunks.first.text.length);
    expect(result.fluency.referenceLevel, inInclusiveRange(1, 4));
  });

  test('セッション情報がなければ流暢さはunavailable相当になる', () {
    final chunks = [
      TranscriptChunk(text: 'テスト', recognizedAt: DateTime(2026, 1, 1)),
    ];
    final result = JsstScoringService.score(chunks);

    expect(result.fluency.capturedSeconds, 0);
    expect(result.fluency.referenceLevel, 1);
  });

  test('短すぎる文字起こしはcombinedReferenceLevelでnullになる（参考レベル算出対象外）', () {
    final chunks = [
      TranscriptChunk(text: 'うん', recognizedAt: DateTime(2026, 1, 1)),
    ];
    final result = JsstScoringService.score(chunks);

    expect(JsstScoringService.isEligibleForReferenceLevel(result), isFalse);
    expect(JsstScoringService.combinedReferenceLevel(result), isNull);
  });

  test('十分な長さの日本語発話はcombinedReferenceLevelが1〜4の範囲で算出される', () {
    final started = DateTime(2026, 1, 1, 10, 0, 0);
    final chunks = [
      TranscriptChunk(
        text: '最近、日本語の勉強を頑張っているので、少しずつ話せるようになってきたと思います。',
        recognizedAt: started.add(const Duration(seconds: 1)),
      ),
    ];
    final result = JsstScoringService.score(
      chunks,
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    );

    expect(JsstScoringService.isEligibleForReferenceLevel(result), isTrue);
    final level = JsstScoringService.combinedReferenceLevel(result);
    expect(level, isNotNull);
    expect(level, inInclusiveRange(1, 4));
  });
}
