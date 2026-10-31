import '../models/vocab_test_session.dart';
import '../models/vocabulary_entry.dart';
import '../services/learner_answer_language.dart';
import 'google_ai_search.dart';
import 'learner_friendly_japanese.dart';

/// レイヤーⅠ「語彙を増やす」単語テスト用のChrome AIプロンプト。
/// [PronunciationAiPromptTemplate]と同じ組み立て方式を使うが、固定カテゴリを
/// 持たない語彙テストのため、評価は5カテゴリ別ではなく「各問の正誤＋総合
/// 1〜5点」という単純な形で依頼する。
///
/// 録音した音声そのものはこのプロンプトに含めない（含められない）。各問、
/// 日本語の単語（読みがあれば併記）と、学習者がベトナム語/英語で答えた内容を
/// 端末STTでテキスト化した結果を示し、その訳として妥当かどうかを判定させる。
abstract final class VocabularyAiPromptTemplate {
  /// AIに要求する固定JSON出力形式。[VocabularyEvaluation.fromJson]が
  /// そのまま読み込める形。
  static const _jsonSchema = '''
{
  "questionEvaluations": [
    {"correct": true または false, "feedback": "短いフィードバック"},
    ... (出題順に、質問と同じ件数だけ)
  ],
  "overallScore": 1〜5の整数,
  "summary": "全体講評"
}''';

  /// [questions]（出題した単語・読み・学習者の回答）を含めた語彙評価
  /// プロンプトを組み立てる。1秒チェックは既に機械採点済みなのでここには
  /// 載せない。Chrome AIの結果へ後から先頭に付け足す。
  static String evaluationPrompt({
    required List<VocabTestQuestion> questions,
    required String lang,
    bool keyboardInput = false,
  }) {
    final copy = _evaluationCopy(lang, keyboardInput: keyboardInput);
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

  static String _questionLine(int number, VocabTestQuestion q) {
    final learnerAnswer = _sanitizeLearnerAnswer(q.sttResult);
    final answerLang = LearnerAnswerLanguageDetector.fromCode(
          q.answerLanguageCode,
        ) ??
        LearnerAnswerLanguageDetector.detect(q.sttResult);
    final reading = q.entry.reading.trim();
    final expectation = _expectationClause(q.entry, answerLang);
    return '$number. word: ${q.entry.word}'
        '${reading.isEmpty ? '' : ' / reading: $reading'} / '
        'learnerAnswerLanguage: ${_answerLanguageLabel(answerLang)} / '
        '$expectation / '
        'learnerAnswer: $learnerAnswer';
  }

  static String _answerLanguageLabel(LearnerAnswerLanguage language) =>
      switch (language) {
        LearnerAnswerLanguage.vi => 'Vietnamese',
        LearnerAnswerLanguage.en => 'English',
        LearnerAnswerLanguage.ja => 'Japanese',
      };

  static String _expectationClause(
    VocabularyEntry entry,
    LearnerAnswerLanguage answerLang,
  ) {
    return switch (answerLang) {
      LearnerAnswerLanguage.ja =>
        'evaluationCriterion: judge whether learnerAnswer correctly explains '
            'the meaning of the Japanese word in Japanese',
      LearnerAnswerLanguage.en when entry.translationLang == 'en' =>
        'expectedTranslation (English): ${entry.translation}',
      LearnerAnswerLanguage.en =>
        'referenceTranslation (Vietnamese): ${entry.translation} / '
            'accept equivalent English translations and close synonyms',
      LearnerAnswerLanguage.vi =>
        'expectedTranslation (Vietnamese): ${entry.translation}',
    };
  }

  /// 改行や制御文字を含むとプロンプトが壊れやすいため、1行に正規化する。
  static String _sanitizeLearnerAnswer(String? raw) {
    if (raw == null) return '(none)';
    final collapsed = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return collapsed.isEmpty ? '(none)' : collapsed;
  }

  /// プロンプトと、それを開くためのURL（長い場合は貼り付け必須）を返す。
  static ChromeAiLaunchPlan evaluationLaunch({
    required List<VocabTestQuestion> questions,
    required String lang,
    bool keyboardInput = false,
  }) {
    final prompt = evaluationPrompt(
      questions: questions,
      lang: lang,
      keyboardInput: keyboardInput,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: prompt, lang: lang);
  }

  static ({
    String header,
    String questionsHeading,
    String formatHeading,
    String jsonInstructionNote,
  })
  _evaluationCopy(String lang, {bool keyboardInput = false}) => switch (lang) {
    'en' => (
      header: keyboardInput
          ? 'You are a Japanese vocabulary evaluation coach. Below is a '
                'vocabulary quiz record from a learner. For each question you '
                'are given a Japanese word (with its reading, if available), '
                'the language of the learner\'s typed answer '
                '(learnerAnswerLanguage), how to judge that answer, and what '
                'the learner typed (learnerAnswer). Judge each answer according '
                'to learnerAnswerLanguage: for Vietnamese or English, compare '
                'against the expected or reference translation; for Japanese, '
                'judge whether the explanation correctly conveys the word\'s '
                'meaning. Accept close synonyms and minor phrasing differences. '
                'Then give an overall vocabulary comprehension score from 1 to 5.'
          : 'You are a Japanese vocabulary evaluation coach. Below is a '
                'vocabulary quiz record from a learner. For each question you are '
                'given a Japanese word (with its reading, if available), the '
                'language the learner spoke in (learnerAnswerLanguage), how to '
                'judge that answer, and what the learner said as a spoken '
                'answer, transcribed by the operating system speech-recognition '
                'service (learnerAnswer). The actual recorded audio is NOT '
                'included here. Judge each answer according to '
                'learnerAnswerLanguage. Accept close synonyms and minor '
                'phrasing differences, not just an exact string match, then '
                'give an overall vocabulary comprehension score from 1 to 5.',
      questionsHeading: '[Questions and the learner\'s answers]',
      formatHeading:
          '[Output format (respond with ONLY this JSON, no text before or after)]',
      jsonInstructionNote:
          'questionEvaluations must have exactly one entry per question, in '
          'the same order. overallScore must be an integer from 1 to 5. '
          'Write feedback and summary in English.',
    ),
    'vi' => (
      header: keyboardInput
          ? 'Bạn là huấn luyện viên đánh giá vốn từ vựng tiếng Nhật. Dưới đây '
                'là bản ghi bài kiểm tra từ vựng của một người học. Với mỗi câu '
                'hỏi, bạn được cung cấp một từ tiếng Nhật (kèm cách đọc nếu có), '
                'ngôn ngữ câu trả lời người học đã gõ (learnerAnswerLanguage), '
                'tiêu chí chấm, và câu trả lời đã gõ (learnerAnswer). Chấm theo '
                'learnerAnswerLanguage: tiếng Việt/Anh thì so với bản dịch mong '
                'đợi hoặc tham chiếu; tiếng Nhật thì đánh giá xem giải thích có '
                'đúng nghĩa từ hay không. Chấp nhận từ đồng nghĩa gần nghĩa và '
                'cách diễn đạt hơi khác, sau đó cho điểm tổng quan 1-5.'
          : 'Bạn là huấn luyện viên đánh giá vốn từ vựng tiếng Nhật. Dưới đây '
                'là bản ghi bài kiểm tra từ vựng của một người học. Với mỗi câu '
                'hỏi, bạn được cung cấp một từ tiếng Nhật (kèm cách đọc nếu có), '
                'ngôn ngữ người học đã nói (learnerAnswerLanguage), tiêu chí '
                'chấm, và câu trả lời nói được chuyển thành văn bản bởi nhận '
                'dạng giọng nói của hệ điều hành (learnerAnswer). Âm thanh ghi '
                'âm thực tế KHÔNG được đính kèm. Chấm theo learnerAnswerLanguage, '
                'chấp nhận từ đồng nghĩa gần nghĩa, sau đó cho điểm tổng quan 1-5.',
      questionsHeading: '[Danh sách câu hỏi và câu trả lời của người học]',
      formatHeading:
          '[Định dạng đầu ra (chỉ trả lời bằng JSON này, không thêm văn bản trước hoặc sau)]',
      jsonInstructionNote:
          'questionEvaluations phải có đúng một mục cho mỗi câu hỏi, theo '
          'đúng thứ tự. overallScore phải là số nguyên từ 1 đến 5. Viết '
          'feedback và summary bằng tiếng Việt.',
    ),
    _ => (
      header: keyboardInput
          ? 'あなたは日本語語彙の評価コーチです。以下は学習者の単語テストの'
                '記録です。各問題について、日本語の単語（読みがあれば併記）、'
                '学習者がキーボードで入力した回答の言語（learnerAnswerLanguage）、'
                '採点基準、そして入力内容（learnerAnswer）を示します。'
                'learnerAnswerLanguageに応じて採点してください。ベトナム語・'
                '英語なら期待訳または参考訳と比較し、日本語なら単語の意味を'
                '正しく説明できているかを判定してください（近い同義語や言い回しの'
                '違いも許容）。そのうえで語彙理解度の総合評価を1〜5点で'
                '付けてください。'
          : 'あなたは日本語語彙の評価コーチです。以下は学習者の単語テストの'
                '記録です。各問題について、日本語の単語（読みがあれば併記）、'
                '学習者が話した言語（learnerAnswerLanguage）、採点基準、そして'
                '口頭回答を端末の音声認識（STT）でテキスト化した結果'
                '（learnerAnswer）を示します。録音した音声そのものはここに'
                '含まれていません。learnerAnswerLanguageに応じて採点し、'
                '近い同義語や言い回しの違いも許容してください。そのうえで'
                '語彙理解度の総合評価を1〜5点で付けてください。',
      questionsHeading: '【出題内容と学習者の回答】',
      formatHeading: '【出力フォーマット（必ず次のJSON形式のみで回答し、前後に説明文を付けないでください）】',
      jsonInstructionNote:
          'questionEvaluationsは出題順に質問と同じ件数だけ含めてください。'
          'overallScoreは1〜5の整数にしてください。feedbackとsummaryは'
          '日本語で書いてください。$learnerFriendlyJapaneseAdvice',
    ),
  };
}
