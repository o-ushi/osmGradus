import '../models/pronunciation_exercise.dart';
import '../models/pronunciation_practice_session.dart';
import 'google_ai_search.dart';
import 'pronunciation_ai_json_schema.dart';

/// レイヤーⅤ「うまく日本語を発音できない」用のChrome AIプロンプト。
/// `AIPromptTemplate`（お題の取り込み）と同じURL組み立て方式を使うが、
/// 固定文ではなく10問（各カテゴリ2問）の期待文・端末STT結果を差し込んだ
/// 発音診断プロンプトを毎回組み立てる点が異なる。
///
/// 録音した音声そのものはこのプロンプトに含めない（含められない）。
/// 期待文と端末STT結果の文字列としての違いから読み取れる範囲の
/// 「参考評価」を、5カテゴリそれぞれ1〜5点で依頼し、
/// [PronunciationEvaluation]の形にそのまま合流できる固定JSON形式で
/// 回答させる（実際の解析は[PronunciationAiResponseParser]が担う）。
///
/// osmGenkiの [ChromeAiPrompts.recordingAnalysis] と同様、[lang]（ja / en / vi）
/// に応じてプロンプト全体を切り替える。
abstract final class PronunciationAiPromptTemplate {
  /// AIに要求する固定JSON出力形式。[PronunciationAiJsonSchema.template]を共有。
  static const _jsonSchema = PronunciationAiJsonSchema.template;

  /// 10問分の[questions]（期待文・かな読み・対象表現・端末STT結果）を含めた
  /// 発音評価プロンプトを組み立てる。
  static String evaluationPrompt({
    required List<PronunciationPracticeQuestion> questions,
    required String lang,
  }) {
    final copy = _evaluationCopy(lang);
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln(copy.questionsHeading);
    for (var i = 0; i < questions.length; i++) {
      buffer.writeln(_questionLine(i + 1, questions[i]));
    }
    buffer
      ..writeln()
      ..writeln(copy.formatHeading)
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln(copy.jsonInstructionNote);
    return buffer.toString();
  }

  static String _questionLine(int number, PronunciationPracticeQuestion q) {
    final recognized = q.sttResult?.trim();
    final targets = q.exercise.targetExpressions.join('、');
    final deviceTranscript = (recognized == null || recognized.isEmpty)
        ? '(none)'
        : recognized;
    return '$number. category: ${q.exercise.category.storageKey} / '
        'sentence: ${q.exercise.sentence} / '
        'reading: ${q.exercise.reading} / '
        'targetExpressions: $targets / '
        'deviceTranscript: $deviceTranscript';
  }

  /// osmWashabeの `webSearchURL(prefilling:)` と同じ組み立て方（GoogleのAIモード
  /// 検索 `udm=50` にプロンプトを差し込む）。
  static Uri evaluationSearchUrl({
    required List<PronunciationPracticeQuestion> questions,
    required String lang,
  }) {
    final query = _searchQuery(
      evaluationPrompt(questions: questions, lang: lang),
      lang,
    );
    return GoogleAiSearch.buildUrl(query);
  }

  static ({
    String header,
    String questionsHeading,
    String formatHeading,
    String jsonInstructionNote,
  })
  _evaluationCopy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese pronunciation evaluation coach. Below is a '
          'pronunciation practice record from a Vietnamese-speaking learner. '
          'For each question you are given the expected sentence '
          '(sentence/reading) and what the learner said, transcribed '
          'by the operating system speech-recognition service '
          '(deviceTranscript). The actual '
          'recorded audio is NOT included here, so you are not judging it '
          'directly. Based only on the textual differences between the '
          'expected sentence and the STT result (dropped sounds, '
          'misrecognitions, unnatural breaks, etc.), give a reference '
          'evaluation for each of 5 categories '
          '(tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, sokuon=促音) '
          'on a 1-5 scale.',
      questionsHeading: '[Questions and speech recognition results]',
      formatHeading:
          '[Output format (respond with ONLY this JSON, no text before or after)]',
      jsonInstructionNote:
          'score must be an integer from 1 to 5. confidence must be one of '
          'low/medium/high. Write feedback and summary in English.',
    ),
    'vi' => (
      header:
          'Bạn là huấn luyện viên đánh giá phát âm tiếng Nhật. Dưới đây là '
          'bản ghi luyện phát âm của một người học tiếng Việt. Với mỗi câu '
          'hỏi, bạn được cung cấp câu mong đợi (sentence/reading) và nội '
          'dung người học đã nói, được dịch vụ nhận dạng giọng nói của hệ điều hành chuyển thành văn bản '
          '(deviceTranscript). Âm thanh ghi âm thực tế KHÔNG được đính kèm '
          'ở đây, vì vậy bạn không trực tiếp nghe và đánh giá. Chỉ dựa trên '
          'sự khác biệt về văn bản giữa câu mong đợi và kết quả STT (rơi '
          'âm, nhận dạng sai, ngắt câu không tự nhiên, v.v.), hãy đưa ra '
          'đánh giá tham khảo cho từng nhóm trong 5 nhóm '
          '(tsu="つ", zRow="ざ・ず・ぞ", rRow=ラ行, longVowel=長音, sokuon=促音) '
          'theo thang điểm 1-5.',
      questionsHeading: '[Danh sách câu hỏi và kết quả nhận dạng giọng nói]',
      formatHeading:
          '[Định dạng đầu ra (chỉ trả lời bằng JSON này, không thêm văn bản trước hoặc sau)]',
      jsonInstructionNote:
          'score phải là số nguyên từ 1 đến 5. confidence phải là low, '
          'medium hoặc high. Viết feedback và summary bằng tiếng Việt.',
    ),
    _ => (
      header:
          'あなたは日本語発音の評価コーチです。以下はベトナム語母語話者の発音練習'
          '記録です。各問題について、期待する文（sentence/reading）と、学習者の'
          '発話を端末の音声認識（STT）でテキスト化した結果（deviceTranscript）を'
          '示します。録音した音声そのものはここに含まれておらず、あなたが直接'
          '聞いて判定しているわけではありません。期待文とSTT結果の文字列としての'
          '違い（脱落・誤変換・不自然な区切りなど）から読み取れる範囲の'
          '「参考評価」として、5つのカテゴリ（tsu=「つ」、zRow=「ざ・ず・ぞ」、'
          'rRow=ラ行、longVowel=長音、sokuon=促音）それぞれを1〜5点で'
          '評価してください。',
      questionsHeading: '【出題内容と音声認識結果】',
      formatHeading: '【出力フォーマット（必ず次のJSON形式のみで回答し、前後に説明文を付けないでください）】',
      jsonInstructionNote:
          'scoreは1〜5の整数、confidenceはlow/medium/highのいずれかにしてください。'
          'feedbackとsummaryは日本語で書いてください。',
    ),
  };

  /// [lang]に応じた「◯◯語で回答してください」という接頭辞を付ける。
  ///
  /// プロンプト本文自体は[_evaluationCopy]で[lang]ごとに書き分けているが、
  /// 検索クエリの冒頭にも明示的な言語指定を置くことで、Google側が既定の
  /// 検索言語（日本語）に引っ張られて出力言語がプロンプト本文の指示と
  /// ずれてしまうのを防ぐ。以前はここが常に「日本語で」固定になっており、
  /// [lang]がen/viのときにプロンプト本文の指示と矛盾し、JSON形式が崩れて
  /// 解析に失敗する原因になっていた。
  static String _searchQuery(String prompt, String lang) {
    final prefix = switch (lang) {
      'en' => 'In English, ',
      'vi' => 'Bằng tiếng Việt, ',
      _ => '日本語で ',
    };
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return prefix;
    if (trimmed.startsWith(prefix)) return trimmed;
    return '$prefix$trimmed';
  }
}
