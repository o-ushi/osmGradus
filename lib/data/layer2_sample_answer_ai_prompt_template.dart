import '../models/question_prompt.dart';
import 'google_ai_search.dart';

/// レイヤーⅡ「解答例」用：問題文（＋状況条件）から、日本語スピーキング練習用の
/// 「約45秒で話せる模範解答」をChrome AIに1つ作成させるプロンプト。
///
/// [QuestionPromptSummaryAiPromptTemplate]（Ⅰ〜Ⅴを横断した総評）とは異なり、
/// この問題文自体への回答例を、口語・自然な話し言葉で1つだけ依頼する
/// （PREPの流れは推奨するが見出しラベルは強制しない）。依頼文（見出し・指示）
/// の言語は[lang]（ja/en/vi）で切り替わるが、返してもらう模範解答本文は
/// 日本語スピーキング練習用のため、依頼文の言語によらず常に日本語で書くよう
/// 明示する。
///
/// 返答フォーマットは `[質問]` / `[日本語]` / `[Romaji]` の3ブロック構成
/// （見出しは依頼文の言語によらず常にこの半角ブラケット表記で固定）。
/// `QuestionPrompt.sampleAnswer` にはこのプレーンテキストがそのまま保存され、
/// レイヤーⅡ（`TextViewSheet`）・レイヤーⅣ（閲覧専用）で表示される。
abstract final class Layer2SampleAnswerAiPromptTemplate {
  Layer2SampleAnswerAiPromptTemplate._();

  /// [prompt]（本文・シチュエーションの条件文があればそれも含む）から
  /// 模範解答の依頼文を組み立てる。
  static String prompt({
    required QuestionPrompt prompt,
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
      ..writeln(copy.instruction);
    return buffer.toString();
  }

  /// 短い依頼でも URL の `q` に載せて開き、模範解答がすぐ出る経路を使う。
  /// （「AIモード入口だけ開いて貼り付け」だと、貼る前の案内文では操作列の
  /// コピーがグレーのまま無反応になる実機報告がある。Google側のUI制限で
  /// アプリからは押せないため、回答が生成される起動に戻す。）
  static ChromeAiLaunchPlan buildLaunchPlan({
    required QuestionPrompt prompt,
    required String lang,
  }) {
    final text = Layer2SampleAnswerAiPromptTemplate.prompt(
      prompt: prompt,
      lang: lang,
    );
    return GoogleAiSearch.buildLaunchPlan(prompt: text, lang: lang);
  }

  static ({
    String header,
    String questionLabel,
    String conditionLabel,
    String instruction,
  })
  _copy(String lang) => switch (lang) {
    'en' => (
      header:
          'You are a Japanese speaking coach. For the question below, '
          'create ONE sample answer of about 45 seconds of spoken length '
          'that a learner can use for speaking practice.',
      questionLabel: 'Question',
      conditionLabel: 'Situation',
      instruction:
          'Write it in natural, conversational spoken Japanese (a '
          'Point-Reason-Example flow is recommended, but do not add '
          'section labels like "Point:"). About 150-250 Japanese '
          'characters is a rough guide - do not force an exact count. '
          'The sample answer itself must always be written in Japanese, '
          'regardless of the language of this instruction. '
          'Reply in plain text only (no JSON, no markdown headings), with '
          'no preamble or repetition of this request, using exactly these '
          'three headings in this order, each followed by its content on '
          'the next line - keep the headings themselves in Japanese '
          'brackets exactly as shown, regardless of the language of this '
          'instruction: '
          '"[質問]" (the question above, including the situation if any, '
          'as-is), then "[日本語]" (the ~45-second spoken sample answer '
          'described above), then "[Romaji]" (a romanization of that '
          '"[日本語]" answer, Hepburn-leaning and optimized for '
          'readability - long vowels may use common notation).',
    ),
    'vi' => (
      header:
          'Bạn là giáo viên luyện nói tiếng Nhật. Với câu hỏi bên dưới, '
          'hãy tạo MỘT câu trả lời mẫu có độ dài nói được trong khoảng '
          '45 giây để người học luyện nói.',
      questionLabel: 'Câu hỏi',
      conditionLabel: 'Tình huống',
      instruction:
          'Hãy viết bằng tiếng Nhật khẩu ngữ, tự nhiên (nên theo dòng '
          'chảy Kết luận→Lý do→Ví dụ, nhưng không cần thêm nhãn tiêu đề '
          'như "Kết luận:"). Khoảng 150-250 ký tự tiếng Nhật chỉ là gợi '
          'ý, không cần đúng chính xác. Nội dung câu trả lời mẫu luôn '
          'phải viết bằng tiếng Nhật, bất kể ngôn ngữ của hướng dẫn này. '
          'Chỉ trả lời bằng văn bản thường (không JSON, không tiêu đề '
          'markdown), không thêm lời mở đầu hay lặp lại yêu cầu này, và '
          'dùng đúng 3 tiêu đề sau theo đúng thứ tự này, mỗi tiêu đề có '
          'nội dung ngay ở dòng tiếp theo - giữ nguyên các tiêu đề bằng '
          'dấu ngoặc vuông tiếng Nhật như bên dưới, bất kể ngôn ngữ của '
          'hướng dẫn này: '
          '"[質問]" (câu hỏi ở trên, kèm tình huống nếu có, giữ nguyên), '
          'sau đó "[日本語]" (câu trả lời mẫu nói được trong ~45 giây như '
          'mô tả ở trên), rồi "[Romaji]" (phiên âm La-tinh của câu trả '
          'lời "[日本語]" đó, ưu tiên kiểu Hepburn và dễ đọc - âm dài có '
          'thể dùng cách viết thông dụng).',
    ),
    _ => (
      header:
          'あなたは日本語スピーキング指導の専門家です。以下の問題文について、'
          '学習者が話す練習に使える「約45秒で話せる模範解答」を1つ作成して'
          'ください。',
      questionLabel: '問題文',
      conditionLabel: '状況',
      instruction:
          '口語・自然な話し言葉で書いてください（結論→理由→具体例の流れを'
          '推奨しますが、「結論：」のような見出しラベルは付けないでください）。'
          '目安として150〜250文字程度で構いませんが、厳密な文字数は気にしな'
          'くてよいです。模範解答の本文は必ず日本語で書いてください。'
          'プレーンテキストのみで回答し（JSONやMarkdown見出しは不要）、'
          '前置きやこの依頼文の繰り返しは書かず、次の3つの見出しをこの順で'
          '使い、各見出しの直後の行から本文を続けてください（見出しは半角'
          'ブラケットのまま、変更・翻訳しないでください）：'
          '「[質問]」（上記の問題文。状況条件があればそれも含めてそのまま）、'
          '続けて「[日本語]」（上記の約45秒で話せる模範解答）、'
          '続けて「[Romaji]」（その「[日本語]」の模範解答のローマ字書き起'
          'こし。ヘボン式寄り・読みやすさ優先。長音は一般的な表記でよい）。',
    ),
  };
}
