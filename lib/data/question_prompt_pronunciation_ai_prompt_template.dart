import 'google_ai_search.dart';
import 'learner_friendly_japanese.dart';
import 'pronunciation_ai_json_schema.dart';

/// レイヤーⅤ「問題文一覧から選ぶ」用のChrome AIプロンプト（Step 6）。
///
/// [LongReadingAiPromptTemplate]（長文の冒頭抜粋を音読し、期待文との一致度を
/// 見る）とは異なり、対象はレイヤーⅠ〜Ⅳと同じ「問題文」への即興の口頭回答。
/// あらかじめ用意された文章の音読ではないため「期待文との一致度」という
/// 枠組みは使わず、[transcript]（回答の端末STT結果）に実際に現れる発音を
/// そのまま参考評価してもらう（[PronunciationAiPromptTemplate]の10問版に近い
/// 考え方だが、対象は「問題文」1件への回答のみで期待文比較は行わない）。
///
/// 出力JSONの形は他の発音評価プロンプトと共通（[PronunciationAiJsonSchema]の
/// `categoryEvaluations`/`summary`）にし、解析も同じ
/// [PronunciationAiResponseParser]・[PronunciationEvaluation]をそのまま使う。
abstract final class QuestionPromptPronunciationAiPromptTemplate {
  static const _jsonSchema = PronunciationAiJsonSchema.template;

  /// プロンプトに含める問題文（冒頭抜粋）の上限文字数
  /// （[LongReadingAiPromptTemplate.maxArticleExcerptChars]と同じ考え方）。
  static const maxQuestionExcerptChars = 200;

  /// プロンプトに含める文字起こしの上限文字数
  /// （[LongReadingAiPromptTemplate.maxTranscriptChars]と同じ考え方）。
  static const maxTranscriptChars = 150;

  static String _clip(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '(none)';
    return trimmed.length <= maxChars
        ? trimmed
        : trimmed.substring(0, maxChars);
  }

  /// [questionBody]（問題文の冒頭抜粋）と、それへの口頭回答を文字起こしした
  /// [transcript]から発音評価プロンプトを組み立てる。
  static String evaluationPrompt({
    required String questionBody,
    required String transcript,
    required String lang,
  }) {
    final copy = _evaluationCopy(lang);
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln(
        '${copy.questionLabel}: ${_clip(questionBody, maxQuestionExcerptChars)}',
      )
      ..writeln(
        '${copy.transcriptLabel}: ${_clip(transcript, maxTranscriptChars)}',
      )
      ..writeln()
      ..writeln(copy.formatHeading)
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln(copy.jsonInstructionNote);
    return buffer.toString();
  }

  static ChromeAiLaunchPlan buildLaunchPlan({
    required String questionBody,
    required String transcript,
    required String lang,
  }) {
    final prompt = evaluationPrompt(
      questionBody: questionBody,
      transcript: transcript,
      lang: lang,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: prompt, lang: lang);
  }

  static ({
    String header,
    String questionLabel,
    String transcriptLabel,
    String formatHeading,
    String jsonInstructionNote,
  })
  _evaluationCopy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese pronunciation coach. A learner answered the '
          'following question aloud in Japanese, spontaneously (not reading '
          'pre-written text). deviceTranscript is the on-device '
          'speech-recognition result of their answer (no audio included). '
          'Based only on what actually appears in the transcript, give a '
          '1-5 reference score for each pronunciation category that '
          'appears (tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, '
          'sokuon=促音); omit categories that do not appear.',
      questionLabel: 'Question',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '[Output format (respond with ONLY this JSON)]',
      jsonInstructionNote:
          'score: integer 1-5. confidence: low/medium/high. Only include '
          'categories that appear in the transcript. Write feedback and '
          'summary in English.',
    ),
    'vi' => (
      header:
          'Bạn là huấn luyện viên phát âm tiếng Nhật. Người học đã trả lời '
          'câu hỏi sau bằng tiếng Nhật, ngay tại chỗ (không đọc văn bản '
          'chuẩn bị trước). deviceTranscript là kết quả nhận dạng giọng nói '
          'trên máy cho câu trả lời đó (không có âm thanh). Chỉ dựa trên '
          'những gì thực sự xuất hiện trong bản ghi, hãy chấm điểm tham '
          'khảo 1-5 cho mỗi nhóm phát âm xuất hiện '
          '(tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, sokuon=促音); '
          'bỏ qua nhóm không xuất hiện.',
      questionLabel: 'Câu hỏi',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '[Chỉ trả lời bằng JSON này]',
      jsonInstructionNote:
          'score là số nguyên 1-5. confidence là low/medium/high. Chỉ đưa '
          'vào nhóm xuất hiện trong bản ghi. Viết feedback và summary bằng '
          'tiếng Việt.',
    ),
    _ => (
      header:
          'あなたは日本語発音の評価コーチです。学習者は以下の質問に、あらかじめ'
          '用意された文章の音読ではなく、その場で日本語で口頭回答しました。'
          'deviceTranscriptは端末STTによるその回答の文字起こしで、録音音声'
          '自体は含まれません。文字起こしに実際に現れる発音カテゴリだけを'
          '（tsu=「つ」、zRow=「ざ・ず・ぞ」、rRow=ラ行、longVowel=長音、'
          'sokuon=促音）1〜5点で参考評価してください'
          '（現れないカテゴリはcategoryEvaluationsから省略）。',
      questionLabel: '質問',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '【出力形式（このJSONのみで回答してください）】',
      jsonInstructionNote:
          'scoreは1〜5の整数、confidenceはlow/medium/highのいずれか。'
          '文字起こしに現れるカテゴリだけを含め、feedbackとsummaryは日本語で'
          '書いてください。$learnerFriendlyJapaneseAdvice',
    ),
  };
}
