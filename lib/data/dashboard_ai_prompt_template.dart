import '../models/pronunciation_exercise.dart';
import '../models/saved_pronunciation_check.dart';
import '../models/saved_scoring_result.dart';
import '../models/saved_vocabulary_check.dart';
import '../services/dashboard_summary_service.dart';
import '../services/jsst_scoring_service.dart';
import 'google_ai_search.dart';

/// ダッシュボード用：直近のレイヤーⅠ・Ⅳ・Ⅴ履歴から総合アドバイスを依頼する
/// Chrome AIプロンプト。
abstract final class DashboardAiPromptTemplate {
  static const recentLimit = DashboardSummaryService.recentLimit;

  /// 直近[recentLimit]件ずつの履歴を埋め込んだアドバイス依頼文。
  static String advicePrompt({
    required List<SavedScoringResult> scoringResults,
    required List<SavedPronunciationCheck> pronunciationChecks,
    required List<SavedVocabularyCheck> vocabularyChecks,
    required String lang,
  }) {
    final copy = _copy(lang);
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln(copy.jsstHeading);

    final recentScoring = scoringResults.take(recentLimit).toList();
    if (recentScoring.isEmpty) {
      buffer.writeln(copy.none);
    } else {
      for (var i = 0; i < recentScoring.length; i++) {
        buffer.writeln(_scoringLine(i + 1, recentScoring[i]));
      }
    }

    buffer
      ..writeln()
      ..writeln(copy.pronunciationHeading);

    final recentChecks = pronunciationChecks.take(recentLimit).toList();
    if (recentChecks.isEmpty) {
      buffer.writeln(copy.none);
    } else {
      for (var i = 0; i < recentChecks.length; i++) {
        buffer.writeln(_pronunciationBlock(i + 1, recentChecks[i], lang));
      }
    }

    buffer
      ..writeln()
      ..writeln(copy.vocabularyHeading);

    final recentVocabulary = vocabularyChecks.take(recentLimit).toList();
    if (recentVocabulary.isEmpty) {
      buffer.writeln(copy.none);
    } else {
      for (var i = 0; i < recentVocabulary.length; i++) {
        buffer.writeln(_vocabularyBlock(i + 1, recentVocabulary[i], lang));
      }
    }

    buffer
      ..writeln()
      ..writeln(copy.instruction);
    return buffer.toString();
  }

  static Uri adviceSearchUrl({
    required List<SavedScoringResult> scoringResults,
    required List<SavedPronunciationCheck> pronunciationChecks,
    required List<SavedVocabularyCheck> vocabularyChecks,
    required String lang,
  }) {
    final prompt = advicePrompt(
      scoringResults: scoringResults,
      pronunciationChecks: pronunciationChecks,
      vocabularyChecks: vocabularyChecks,
      lang: lang,
    );
    final query = switch (lang) {
      'en' => prompt.startsWith('In English') ? prompt : 'In English, $prompt',
      'vi' =>
        prompt.startsWith('Bằng tiếng Việt')
            ? prompt
            : 'Bằng tiếng Việt, $prompt',
      _ => GoogleAiSearch.withJapanesePrefix(prompt),
    };
    return GoogleAiSearch.buildUrl(query);
  }

  static String _scoringLine(int number, SavedScoringResult saved) {
    final result = saved.result;
    final level = JsstScoringService.combinedReferenceLevel(result);
    final levelLabel = DashboardSummaryService.jsstBandLabel(level);
    final transcript = result.fullTranscript.trim();
    final excerpt = transcript.isEmpty
        ? '(empty)'
        : (transcript.length > 200
              ? '${transcript.substring(0, 200)}…'
              : transcript);
    final hitStars = saved.hasAiEvaluation ? '${saved.hitStars}/5' : '(none)';
    final prepStars = saved.hasAiEvaluation ? '${saved.prepStars}/5' : '(none)';
    return '$number. date: ${saved.createdAt.toIso8601String()} / '
        'approxLevel: $levelLabel / '
        'keigoVariety: ${result.keigo.varietyScore} / '
        'complexityRatio: ${result.complexity.complexityRatio.toStringAsFixed(2)} / '
        'fluencyLevel: ${result.fluency.referenceLevel} / '
        'hitStars: $hitStars / '
        'prepStars: $prepStars / '
        'transcript: $excerpt';
  }

  static String _pronunciationBlock(
    int number,
    SavedPronunciationCheck check,
    String lang,
  ) {
    final evaluation = check.evaluation;
    if (evaluation == null) {
      final legacy = check.transcript.trim();
      return '$number. date: ${check.createdAt.toIso8601String()} / '
          'evaluation: (none) / '
          'legacyNote: ${legacy.isEmpty ? '(empty)' : legacy}';
    }

    final scores = evaluation.categoryEvaluations.entries
        .map((e) => '${e.key.storageKey}:${e.value.score}')
        .join(', ');
    final summary = evaluation.displaySummary(lang).trim();
    return '$number. date: ${check.createdAt.toIso8601String()} / '
        'scores: [$scores] / '
        'summary: ${summary.isEmpty ? '(none)' : summary}';
  }

  static String _vocabularyBlock(
    int number,
    SavedVocabularyCheck check,
    String lang,
  ) {
    final evaluation = check.evaluation;
    if (evaluation == null) {
      return '$number. date: ${check.createdAt.toIso8601String()} / '
          'evaluation: (none) / '
          'questionCount: ${check.questions.length}';
    }

    final summary = (evaluation.summary ?? '').trim();
    return '$number. date: ${check.createdAt.toIso8601String()} / '
        'overallScore: ${evaluation.overallScore}/5 / '
        'correct: ${evaluation.correctCount}/${evaluation.questionEvaluations.length} / '
        'summary: ${summary.isEmpty ? '(none)' : summary}';
  }

  static ({
    String header,
    String jsstHeading,
    String pronunciationHeading,
    String vocabularyHeading,
    String none,
    String instruction,
  })
  _copy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese conversation coach for Vietnamese-speaking '
          'learners. Below are the learner\'s recent Layer IV (JSST-style '
          'speaking) results, Layer V (pronunciation check) results, and '
          'Layer I (vocabulary check) results. '
          'Give concise, actionable overall advice for what to practice next. '
          'Reply in plain text only (no JSON, no markdown headings). '
          'Keep it to about 4–8 short sentences.',
      jsstHeading: '## Recent Layer IV (JSST-style) results',
      pronunciationHeading: '## Recent Layer V (pronunciation) results',
      vocabularyHeading: '## Recent Layer I (vocabulary check) results',
      none: '(none)',
      instruction:
          'Write overall advice that balances all 5 areas: JSST-style '
          'fluency, how directly answers address the question (hitStars), '
          'how well answers follow a Point-Reason-Example structure '
          '(prepStars), pronunciation, and vocabulary recall. Mention '
          'concrete next steps.',
    ),
    'vi' => (
      header:
          'Bạn là giáo viên luyện hội thoại tiếng Nhật cho người học '
          'nói tiếng Việt. Dưới đây là kết quả gần đây của Lớp IV '
          '(nói theo kiểu JSST), Lớp V (kiểm tra phát âm) và Lớp I '
          '(kiểm tra từ vựng). Hãy đưa lời khuyên tổng hợp, ngắn gọn, '
          'có thể hành động ngay về việc nên luyện gì tiếp theo. Chỉ trả '
          'lời bằng văn bản thường (không JSON, không tiêu đề markdown). '
          'Khoảng 4–8 câu ngắn.',
      jsstHeading: '## Kết quả Lớp IV (kiểu JSST) gần đây',
      pronunciationHeading: '## Kết quả Lớp V (phát âm) gần đây',
      vocabularyHeading: '## Kết quả Lớp I (từ vựng) gần đây',
      none: '(không có)',
      instruction:
          'Viết lời khuyên tổng thể cân bằng cả 5 mặt: độ trôi chảy kiểu '
          'JSST, mức độ trả lời đúng trọng tâm câu hỏi (hitStars), mức độ '
          'tuân theo cấu trúc Kết luận-Lý do-Ví dụ (prepStars), phát âm và '
          'khả năng nhớ từ vựng. Nêu bước tiếp theo cụ thể.',
    ),
    _ => (
      header:
          'あなたはベトナム語を母語とする学習者向けの日本語会話コーチです。'
          '以下は直近のレイヤーⅣ（JSST風の発話）結果、レイヤーⅤ（発音チェック）結果、'
          'レイヤーⅠ（語彙チェック）結果です。'
          '次に何を練習すべきか、簡潔で実行可能な総合アドバイスをください。'
          'プレーンテキストのみで回答し（JSONや見出し記法は不要）、'
          '4〜8文程度にまとめてください。',
      jsstHeading: '## 直近のレイヤーⅣ（JSST風）結果',
      pronunciationHeading: '## 直近のレイヤーⅤ（発音）結果',
      vocabularyHeading: '## 直近のレイヤーⅠ（語彙チェック）結果',
      none: '（なし）',
      instruction:
          'JSST風の流暢さ・的中度（hitStars）・PREP構成（prepStars）・発音・'
          '語彙力の5点をバランスよく踏まえた総合アドバイスと、具体的な次の'
          '一歩を書いてください。',
    ),
  };
}
