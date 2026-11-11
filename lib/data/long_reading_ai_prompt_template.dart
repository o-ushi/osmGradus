import '../models/long_article.dart';
import 'google_ai_search.dart';
import 'learner_friendly_japanese.dart';
import 'pronunciation_ai_json_schema.dart';

/// レイヤーⅤ「長文」音読用のChrome AIプロンプト。
///
/// [PronunciationAiPromptTemplate]（短文10問）と違い、対象は1本の長文と
/// その音読を端末STTでテキスト化した結果のみ。短文のように出題時から
/// カテゴリ（つ/ざ行/ラ行/長音/促音）を狙って作られてはいないため、
/// 本文中に実際に現れるものだけを評価対象にしてよいとAIに明示し、
/// 現れないカテゴリは省略させる（osmCogitoの
/// `CogitoLongReadingPromptBuilder`と同じ考え方）。
///
/// 出力JSONの形は[PronunciationAiJsonSchema]で短文と共通
/// （`categoryEvaluations`/`summary`）にし、解析は同じ
/// [PronunciationAiResponseParser]・[PronunciationEvaluation]をそのまま使う。
///
/// osmCogitoは「本文の冒頭抜粋（[CogitoLongReadingPromptBuilder.maxExpectedChars]
/// =160文字）」「文字起こしの切り詰め（`maxTranscriptChars`=120文字）」
/// 「説明文を短く」の3点で、原則URLプリフィル（[GoogleAiSearch.buildLaunchPlan]の
/// クリップボード貼り付けフォールバックを使わない）に収めている。日本語・
/// ベトナム語はURLエンコード時に1文字あたり最大約9倍に膨れるため、
/// 説明文が長いと本文を切り詰めても7500文字上限を超えてしまう
/// （旧実装は本文の抜粋のみ500文字まで許し、文字起こしを一切切り詰めて
/// おらず、かつ説明文もCogitoよりかなり長かったため、実機で毎回クリップ
/// ボード貼り付けが必要になっていた）。ここではCogitoと同じ3点の対策を移植する。
abstract final class LongReadingAiPromptTemplate {
  static const _jsonSchema = PronunciationAiJsonSchema.template;

  /// プロンプトに含める本文（冒頭抜粋）の上限文字数
  /// （osmCogitoの`maxExpectedChars`=160に相当。Gradusのスキーマは
  /// confidence/feedback/evidenceを含み固定部分がCogitoより長いため、
  /// やや控えめな値にしている）。
  static const maxArticleExcerptChars = 200;

  /// プロンプトに含める文字起こしの上限文字数
  /// （osmCogitoの`maxTranscriptChars`=120に相当）。旧実装はここを
  /// 一切切り詰めておらず、3分の録音をそのまま送っていたため、この上限が
  /// 抜けていたことが7500文字超過の主因だった。
  static const maxTranscriptChars = 150;

  static String _clip(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '(none)';
    return trimmed.length <= maxChars
        ? trimmed
        : trimmed.substring(0, maxChars);
  }

  /// [article]の本文（冒頭抜粋）と、その音読を文字起こしした[transcript]から
  /// 発音評価プロンプトを組み立てる。
  static String evaluationPrompt({
    required LongArticle article,
    required String transcript,
    required String lang,
  }) {
    final copy = _evaluationCopy(lang);
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln(
        '${copy.articleLabel}: ${_clip(article.body, maxArticleExcerptChars)}',
      )
      ..writeln(
        '${copy.transcriptLabel}: ${_clip(transcript, maxTranscriptChars)}',
      )
      ..writeln()
      ..writeln(copy.formatHeading)
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln(copy.jsonInstructionNote)
      ..writeln(PronunciationAiJsonSchema.overallNote(lang));
    return buffer.toString();
  }

  /// [GoogleAiSearch.buildLaunchPlan]で、長すぎる場合はクリップボード貼り付け
  /// へ自動的に切り替わるURL・プロンプトの組を返す（[maxArticleExcerptChars]・
  /// [maxTranscriptChars]で切り詰めているため、通常はこのフォールバックに
  /// 頼らずURLプリフィルに収まる）。
  static ChromeAiLaunchPlan buildLaunchPlan({
    required LongArticle article,
    required String transcript,
    required String lang,
  }) {
    final prompt = evaluationPrompt(
      article: article,
      transcript: transcript,
      lang: lang,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: prompt, lang: lang);
  }

  static ({
    String header,
    String articleLabel,
    String transcriptLabel,
    String formatHeading,
    String jsonInstructionNote,
  })
  _evaluationCopy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese pronunciation coach. A learner read the '
          'opening of a Japanese article aloud. deviceTranscript is the '
          'on-device speech-recognition result of that reading (no audio '
          'included). Based on the textual match with the excerpt, give a '
          '1-5 reference score for each pronunciation category that '
          'actually appears in the excerpt '
          '(tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, sokuon=促音); '
          'omit categories that do not appear.',
      articleLabel: 'Expected excerpt',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '[Output format (respond with ONLY this JSON)]',
      jsonInstructionNote:
          'score: integer 1-5. confidence: low/medium/high. Only include '
          'categories that appear in the excerpt. Write feedback and '
          'summary in English.',
    ),
    'vi' => (
      header:
          'Bạn là huấn luyện viên phát âm tiếng Nhật. Người học đã đọc to '
          'phần đầu một bài viết tiếng Nhật. deviceTranscript là kết quả '
          'nhận dạng giọng nói trên máy (không có âm thanh). Dựa trên mức '
          'khớp với đoạn trích, hãy chấm điểm tham khảo 1-5 cho mỗi nhóm '
          'phát âm thực sự xuất hiện trong đoạn '
          '(tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, sokuon=促音); '
          'bỏ qua nhóm không xuất hiện.',
      articleLabel: 'Đoạn mong đợi',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '[Chỉ trả lời bằng JSON này]',
      jsonInstructionNote:
          'score là số nguyên 1-5. confidence là low/medium/high. Chỉ đưa '
          'vào nhóm xuất hiện trong đoạn. Viết feedback và summary bằng '
          'tiếng Việt.',
    ),
    _ => (
      header:
          'あなたは日本語発音の評価コーチです。学習者が長文の冒頭を音読しました。'
          'deviceTranscriptは端末STTの結果で、録音音声自体は含まれません。'
          '期待する抜粋との一致度から、抜粋に実際に現れる発音カテゴリ'
          '（tsu=「つ」、zRow=「ざ・ず・ぞ」、rRow=ラ行、longVowel=長音、'
          'sokuon=促音）だけを1〜5点で参考評価してください'
          '（現れないカテゴリはcategoryEvaluationsから省略）。',
      articleLabel: '期待する抜粋',
      transcriptLabel: 'deviceTranscript',
      formatHeading: '【出力形式（このJSONのみで回答してください）】',
      jsonInstructionNote:
          'scoreは1〜5の整数、confidenceはlow/medium/highのいずれか。'
          '抜粋に現れるカテゴリだけを含め、feedbackとsummaryは日本語で'
          '書いてください。$learnerFriendlyJapaneseAdvice',
    ),
  };
}
