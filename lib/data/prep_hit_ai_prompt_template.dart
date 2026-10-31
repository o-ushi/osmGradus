import 'google_ai_search.dart';
import 'learner_friendly_japanese.dart';

/// レイヤーⅣ「日本語での表現方法が分からない」の的中度・PREP評価用の
/// Chrome AIプロンプト（osmCogitoの`CogitoEvaluationPromptBuilder`の移植）。
///
/// JSST採点（[JsstScoringService]）はローカルの文字列解析のみで完結するが、
/// 「質問にどれだけ的確に答えられているか（的中度）」「結論→理由→例
/// （PREP）の型にどれだけ沿っているか」はローカル解析では判定できないため、
/// この2点だけをChrome AIに依頼する。1ラウンド分（質問＋回答の文字起こし）
/// だけを送るプロンプトを都度組み立てることで、[GoogleAiSearch.
/// maxPrefillUrlLength]を超えないようにする（長文音読プロンプトの教訓と同じ、
/// 説明文を短く保つ設計）。
abstract final class PrepHitAiPromptTemplate {
  static const _jsonSchema =
      '{"prepStars": 1〜5の整数, "hitStars": 1〜5の整数, '
      '"prepAdvice": "PREPへの一言アドバイス", '
      '"hitAdvice": "的中度への一言アドバイス", '
      '"modelAnswer": "発話を自然な良い日本語に直した文", '
      '"modelAnswerRomaji": "modelAnswer in romaji", '
      '"modelAnswerVi": "modelAnswer in Vietnamese"}';

  /// [questionJa]（お題）と[answerTranscript]（日本語回答の文字起こし）から
  /// 評価プロンプトを組み立てる。[lang]はアプリ表示言語（'ja'/'en'/'vi'）。
  static String buildPrompt({
    required String questionJa,
    required String? answerTranscript,
    required String lang,
  }) {
    final copy = _copy(lang);
    final answer = answerTranscript?.trim();
    final answerText = (answer == null || answer.isEmpty) ? '(none)' : answer;
    final buffer = StringBuffer()
      ..writeln(copy.header)
      ..writeln()
      ..writeln('question: $questionJa')
      ..writeln('answerTranscript: $answerText')
      ..writeln()
      ..writeln(copy.formatHeading)
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln(copy.jsonInstructionNote);
    return buffer.toString();
  }

  /// プロンプトと、それを開くためのURL（長い場合はクリップボード貼り付け
  /// 必須）を返す。
  static ChromeAiLaunchPlan buildLaunchPlan({
    required String questionJa,
    required String? answerTranscript,
    required String lang,
  }) {
    final prompt = buildPrompt(
      questionJa: questionJa,
      answerTranscript: answerTranscript,
      lang: lang,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: prompt, lang: lang);
  }

  static ({String header, String formatHeading, String jsonInstructionNote})
  _copy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese speaking coach. Below is a question a learner '
          'answered aloud in Japanese, together with what they said, '
          'transcribed by the device speech-recognition service '
          '(answerTranscript). The actual recorded audio is NOT included '
          'here. Rate two DIFFERENT things on a 1-5 scale, and give a '
          'SEPARATE short (1-2 sentence) piece of coaching advice for each '
          '(do not merge them into one comment): prepStars = how well the '
          'answer follows a Point → Reason → Example (PREP) structure, with '
          'coaching advice about that in the "prepAdvice" field; hitStars = '
          'how directly the answer addresses the question asked, with '
          'coaching advice about that in the "hitAdvice" field. Both advice '
          'fields must be in English. Also set "modelAnswer" to one rewrite '
          'of answerTranscript in natural, correct Japanese that keeps the '
          'learner\'s meaning (do not translate it). Use "" if there is no '
          'speech.',
      formatHeading:
          '[Output format (respond with ONLY this JSON object, '
          'no text before or after)]',
      jsonInstructionNote:
          'prepStars and hitStars must each be an integer from 1 to 5. '
          'prepAdvice and hitAdvice must each be a short, separate string '
          'in English (do not combine them). modelAnswer must be natural '
          'Japanese, or "" if there is no speech.',
    ),
    'vi' => (
      header:
          'Bạn là huấn luyện viên nói tiếng Nhật. Dưới đây là một câu hỏi '
          'mà người học đã trả lời bằng lời nói bằng tiếng Nhật, cùng với '
          'nội dung đã nói được dịch vụ nhận dạng giọng nói của thiết bị '
          'chuyển thành văn bản (answerTranscript). Âm thanh ghi âm thực '
          'tế KHÔNG được đính kèm ở đây. Hãy chấm hai điều KHÁC NHAU theo '
          'thang điểm 1-5, và đưa ra lời khuyên ngắn (1-2 câu) RIÊNG BIỆT '
          'cho từng điều (không gộp chung thành một nhận xét): prepStars = '
          'câu trả lời tuân theo cấu trúc Kết luận → Lý do → Ví dụ (PREP) '
          'tốt đến mức nào, kèm lời khuyên ở trường "prepAdvice"; hitStars = '
          'câu trả lời có trả lời đúng trọng tâm câu hỏi hay không, kèm lời '
          'khuyên ở trường "hitAdvice". Cả hai trường lời khuyên đều phải '
          'bằng tiếng Việt. Thêm "modelAnswer": một câu viết lại '
          'answerTranscript bằng tiếng Nhật tự nhiên, đúng, giữ nguyên ý '
          '(không dịch). Nếu không có lời nói thì để chuỗi rỗng.',
      formatHeading:
          '[Định dạng đầu ra (chỉ trả lời bằng JSON này, '
          'không thêm văn bản trước hoặc sau)]',
      jsonInstructionNote:
          'prepStars và hitStars phải là số nguyên từ 1 đến 5. '
          'prepAdvice và hitAdvice phải là hai đoạn văn bản ngắn, riêng '
          'biệt bằng tiếng Việt (không gộp chung). modelAnswer là tiếng '
          'Nhật tự nhiên, hoặc chuỗi rỗng nếu không có lời nói.',
    ),
    _ => (
      header:
          'あなたは日本語スピーキングの評価コーチです。以下は学習者が日本語で'
          '口頭回答した質問と、その発話を端末の音声認識（STT）でテキスト化'
          'した結果（answerTranscript）です。録音した音声そのものはここに'
          '含まれていません。次の2点は別々の観点の評価なので、それぞれ'
          '1〜5点で評価したうえで、一言アドバイス（1〜2文）も'
          'それぞれ別々に書いてください（1つにまとめないでください）。'
          'prepStars＝回答が「結論→理由→例」（PREP）の型にどれだけ沿って'
          'いるか（アドバイスは"prepAdvice"）。hitStars＝回答が質問の的を'
          'どれだけ射ているか（アドバイスは"hitAdvice"）。'
          '$learnerFriendlyJapaneseAdvice'
          'modelAnswerには、言いたいことを残したまま、もっと自然で良い'
          '日本語に直した文を1つ書いてください。発話がなければ空にしてください。',
      formatHeading: '【出力形式（このJSONオブジェクトのみで回答し、前後に説明文を付けないでください）】',
      jsonInstructionNote:
          'prepStars・hitStarsはそれぞれ1〜5の整数、prepAdvice・hitAdviceは'
          'それぞれ短い、やさしい日本語にしてください（1つにまとめないこと）。'
          'modelAnswerは自然な日本語の文字列にしてください。',
    ),
  };
}
