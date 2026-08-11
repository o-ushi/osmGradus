import 'question_prompt.dart';
import 'question_prompt_source.dart';
import 'topic_category.dart';

/// 問題文一覧のフィルタ条件（入手元／分野／実施状況の3軸、すべてAND）。
/// 「実施状況」の意味はレイヤーごとに異なる（Ⅰ：理解、Ⅱ：要約記入、
/// Ⅲ：PREP記入、Ⅳ：JSST評点、Ⅴ：発音評点）ため、判定自体は呼び出し側が
/// [QuestionPromptListScreen.isDone]で渡し、ここでは真偽値だけを持つ。
class QuestionPromptFilter {
  const QuestionPromptFilter({this.source, this.field, this.done});

  final QuestionPromptSource? source;
  final TopicCategory? field;

  /// true＝実施済みだけ、false＝未実施だけ、null＝絞り込まない。
  final bool? done;

  bool get isEmpty => source == null && field == null && done == null;

  QuestionPromptFilter copyWith({
    QuestionPromptSource? source,
    bool clearSource = false,
    TopicCategory? field,
    bool clearField = false,
    bool? done,
    bool clearDone = false,
  }) => QuestionPromptFilter(
    source: clearSource ? null : (source ?? this.source),
    field: clearField ? null : (field ?? this.field),
    done: clearDone ? null : (done ?? this.done),
  );

  bool matches(QuestionPrompt prompt, bool Function(QuestionPrompt) isDone) {
    if (source != null && prompt.source != source) return false;
    if (field != null && prompt.field != field) return false;
    if (done != null && isDone(prompt) != done) return false;
    return true;
  }
}
