import 'question_prompt.dart';
import 'topic_category.dart';
import '../services/question_prompt_tab_registry.dart';

/// レイヤーⅡランダム・Ⅲ・Ⅳランダムなど、問題文プールから抽選するときの
/// カテゴリ／タブ選択（`question-prompt-tabs.md`）。
///
/// 「その他」を経由せず、組み込みタブ・ランダム（general 全件）・
/// シチュエーションを1枚のシートで選ぶ。
class QuestionPromptDrawSelection {
  const QuestionPromptDrawSelection._({required this.kind, this.tag});

  /// [tag]は[QuestionPromptTabRegistry.builtInTabKeys]のいずれか。
  const QuestionPromptDrawSelection.tag(String tag)
    : this._(kind: QuestionPromptDrawKind.tagged, tag: tag);

  /// general の全問題文から抽選（タブで絞らない）。
  const QuestionPromptDrawSelection.generalRandom()
    : this._(kind: QuestionPromptDrawKind.generalRandom);

  /// シチュエーション（15+60秒モード専用）。
  const QuestionPromptDrawSelection.situational()
    : this._(kind: QuestionPromptDrawKind.situational);

  final QuestionPromptDrawKind kind;
  final String? tag;

  TopicCategory get category => kind == QuestionPromptDrawKind.situational
      ? TopicCategory.situational
      : TopicCategory.general;

  /// [QuestionPromptService.filter]の`tag`引数。general 全件のときは null。
  String? get filterTag =>
      kind == QuestionPromptDrawKind.tagged ? tag : null;

  /// カテゴリ行の表示用 l10n キー（日本語ソース）。
  String get labelKey => switch (kind) {
    QuestionPromptDrawKind.tagged => tag!,
    QuestionPromptDrawKind.generalRandom => 'ランダム',
    QuestionPromptDrawKind.situational => 'シチュエーション',
  };

  /// 保存済み[QuestionPrompt]から、カテゴリ行の初期選択を推定する
  /// （編集画面用。複数タブのときは先頭の組み込みタブ、なければランダム）。
  static QuestionPromptDrawSelection fromPrompt(QuestionPrompt prompt) {
    if (prompt.category == TopicCategory.situational) {
      return const QuestionPromptDrawSelection.situational();
    }
    for (final tab in QuestionPromptTabRegistry.builtInTabKeys) {
      if (prompt.tags.contains(tab)) {
        return QuestionPromptDrawSelection.tag(tab);
      }
    }
    if (prompt.tags.isNotEmpty) {
      return QuestionPromptDrawSelection.tag(prompt.tags.first);
    }
    return const QuestionPromptDrawSelection.generalRandom();
  }

  /// [TopicCategory]のみ分かっているときの既定（手動追加の初期値など）。
  static QuestionPromptDrawSelection fromTopicCategory(TopicCategory category) {
    return category == TopicCategory.situational
        ? const QuestionPromptDrawSelection.situational()
        : const QuestionPromptDrawSelection.generalRandom();
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionPromptDrawSelection &&
      other.kind == kind &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(kind, tag);
}

enum QuestionPromptDrawKind { tagged, generalRandom, situational }
