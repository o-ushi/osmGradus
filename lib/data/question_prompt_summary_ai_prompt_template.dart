import '../models/pronunciation_exercise.dart';
import '../models/question_prompt.dart';
import 'google_ai_search.dart';
import 'learner_friendly_japanese.dart';
import 'jsst_reference_samples.dart';

/// 総評画面（Step 7）用：1問題文についてレイヤーⅠ〜Ⅴを横断した結果から
/// Chrome AIへ総合アドバイスを依頼するプロンプト。
///
/// [DashboardAiPromptTemplate]が直近の練習履歴を集計するのに対し、こちらは
/// 「1つの問題文」に絞った深掘りアドバイスを依頼する
/// （[QuestionPromptPronunciationAiPromptTemplate]と同じく
/// [GoogleAiSearch.buildLaunchPlan]で長さに応じてURL埋め込み/クリップボード
/// 貼り付けを自動切り替えする）。
abstract final class QuestionPromptSummaryAiPromptTemplate {
  /// [prompt]・[registeredWords]（レイヤーⅠで登録した単語の表記一覧）から
  /// アドバイス依頼文を組み立てる。未記入の項目は各言語の「なし」表記にする。
  static String advicePrompt({
    required QuestionPrompt prompt,
    required List<String> registeredWords,
    required String lang,
  }) {
    final copy = _copy(lang);
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln('${copy.questionLabel}: ${prompt.body}');
    final condition = prompt.situationCondition;
    if (condition != null && condition.isNotEmpty) {
      buffer.writeln('${copy.conditionLabel}: $condition');
    }

    buffer
      ..writeln()
      ..writeln(copy.layer1Heading)
      ..writeln(registeredWords.isEmpty ? copy.none : registeredWords.join('、'))
      ..writeln()
      ..writeln(copy.layer2Heading)
      ..writeln(prompt.summary.isEmpty ? copy.none : prompt.summary)
      ..writeln()
      ..writeln(copy.layer3Heading)
      ..writeln(
        '${copy.conclusionLabel}: '
        '${prompt.conclusion.isEmpty ? copy.none : prompt.conclusion}',
      )
      ..writeln(
        '${copy.reasonLabel}: '
        '${prompt.reason.isEmpty ? copy.none : prompt.reason}',
      )
      ..writeln(
        '${copy.exampleLabel}: '
        '${prompt.example.isEmpty ? copy.none : prompt.example}',
      )
      ..writeln()
      ..writeln(copy.layer4Heading)
      ..writeln(
        'JSST: '
        '${prompt.jsstScore == null ? copy.none : JsstReferenceSamples.levelLabel(prompt.jsstScore)}',
      )
      ..writeln('${copy.hitLabel}: ${prompt.hitScore?.toString() ?? copy.none}')
      ..writeln('PREP: ${prompt.prepScore?.toString() ?? copy.none}')
      ..writeln()
      ..writeln(copy.layer5Heading);

    if (prompt.pronunciationScores.isEmpty) {
      buffer.writeln(copy.none);
    } else {
      for (final category in PronunciationCategory.values) {
        final score = prompt.pronunciationScores[category];
        if (score == null) continue;
        buffer.writeln('${category.label}: $score/5');
      }
    }

    buffer
      ..writeln()
      ..writeln(copy.instruction);
    return buffer.toString();
  }

  static ChromeAiLaunchPlan buildLaunchPlan({
    required QuestionPrompt prompt,
    required List<String> registeredWords,
    required String lang,
  }) {
    final text = advicePrompt(
      prompt: prompt,
      registeredWords: registeredWords,
      lang: lang,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: text, lang: lang);
  }

  static ({
    String header,
    String questionLabel,
    String conditionLabel,
    String layer1Heading,
    String layer2Heading,
    String layer3Heading,
    String conclusionLabel,
    String reasonLabel,
    String exampleLabel,
    String layer4Heading,
    String hitLabel,
    String layer5Heading,
    String none,
    String instruction,
  })
  _copy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese conversation coach for Vietnamese-speaking '
          'learners. Below is one practice question and everything the '
          'learner has recorded about it across Layers I-V so far.',
      questionLabel: 'Question',
      conditionLabel: 'Situation',
      layer1Heading: '## Layer I: words the learner did not know',
      layer2Heading: '## Layer II: summary of their planned answer',
      layer3Heading: '## Layer III: Point-Reason-Example outline',
      conclusionLabel: 'Point',
      reasonLabel: 'Reason',
      exampleLabel: 'Example',
      layer4Heading: '## Layer IV: JSST-style speaking scores',
      hitLabel: 'On-topic score (hitScore)',
      layer5Heading: '## Layer V: pronunciation scores',
      none: '(none)',
      instruction:
          'Give concise, actionable overall advice for this specific '
          'question: what the learner did well, what to fix next, and how '
          'to practice it. Reply in plain text only (no JSON, no markdown '
          'headings). Keep it to about 4-8 short sentences.',
    ),
    'vi' => (
      header:
          'Bạn là giáo viên luyện hội thoại tiếng Nhật cho người học nói '
          'tiếng Việt. Dưới đây là một câu hỏi luyện tập và mọi thứ người '
          'học đã ghi lại về câu hỏi này qua các Lớp I-V.',
      questionLabel: 'Câu hỏi',
      conditionLabel: 'Tình huống',
      layer1Heading: '## Lớp I: từ mà người học chưa biết',
      layer2Heading: '## Lớp II: tóm tắt câu trả lời dự kiến',
      layer3Heading: '## Lớp III: dàn ý Kết luận-Lý do-Ví dụ',
      conclusionLabel: 'Kết luận',
      reasonLabel: 'Lý do',
      exampleLabel: 'Ví dụ',
      layer4Heading: '## Lớp IV: điểm nói theo kiểu JSST',
      hitLabel: 'Độ trúng trọng tâm (hitScore)',
      layer5Heading: '## Lớp V: điểm phát âm',
      none: '(không có)',
      instruction:
          'Hãy đưa lời khuyên tổng hợp, ngắn gọn, có thể hành động ngay '
          'cho riêng câu hỏi này: người học đã làm tốt điều gì, cần sửa '
          'gì tiếp theo, và nên luyện tập như thế nào. Chỉ trả lời bằng '
          'văn bản thường (không JSON, không tiêu đề markdown). Khoảng '
          '4-8 câu ngắn.',
    ),
    _ => (
      header:
          'あなたはベトナム語を母語とする学習者向けの日本語会話コーチです。'
          '以下は1つの練習問題と、レイヤーⅠ〜Ⅴでこの問題文について学習者が'
          'これまでに記録した内容です。',
      questionLabel: '問題文',
      conditionLabel: '状況',
      layer1Heading: '## レイヤーⅠ：分からなかった単語',
      layer2Heading: '## レイヤーⅡ：回答の要約',
      layer3Heading: '## レイヤーⅢ：結論・理由・具体例',
      conclusionLabel: '結論',
      reasonLabel: '理由',
      exampleLabel: '具体例',
      layer4Heading: '## レイヤーⅣ：JSST風スピーキング評点',
      hitLabel: '的中度',
      layer5Heading: '## レイヤーⅤ：発音評点',
      none: '（なし）',
      instruction:
          'この問題文に絞って、できていた点・次に直すべき点・具体的な'
          '練習方法を、簡潔で実行可能な総合アドバイスとして書いてください。'
          'プレーンテキストのみで回答し（JSONや見出し記法は不要）、'
          '4〜8文程度にまとめてください。$learnerFriendlyJapaneseAdvice',
    ),
  };
}
