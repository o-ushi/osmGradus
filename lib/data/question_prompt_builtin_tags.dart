/// 組み込み問題文（[TopicBank]）へのタブ付与マッピング（Step 2）。
///
/// キーは[QuestionPromptService]が組み込みエントリに割り当てる固定ID
/// （`builtin_daily_<index>`/`builtin_business_<index>`、[TopicBank.dailyTopics]/
/// [TopicBank.businessTopics]のindexと対応）。値は[QuestionPromptTabRegistry]の
/// 組み込みタブのstorageKeyのみ（独自タブはここでは使わない）。
///
/// [TopicBank.situationPrompts]（`builtin_situational_*`）は
/// [QuestionPrompt.tags]が常に空のため、ここには含めない。
/// [TopicBank.supplementTopics]は今回も[QuestionPrompt]化しないため対象外
/// （`docs/prompts/question-prompt-tabs.md` Step 1のコメント方針を維持）。
abstract final class QuestionPromptBuiltinTags {
  /// [TopicBank.dailyTopics]のindex別タブ。
  static const Map<int, List<String>> dailyTagsByIndex = {
    0: ['趣味'],
    1: ['趣味'],
    2: ['家族'],
    3: ['趣味'],
    4: ['趣味'],
    5: ['旅行'],
    6: ['健康'],
    7: ['趣味'],
    8: ['家族'],
    9: ['環境'],
  };

  /// [TopicBank.businessTopics]のindex別タブ。全問「会社」を基本とする
  /// （チーム関連の設問等も、職場の話題として一貫させるため個別の追加タブは
  /// 付けない。将来個別に付けたくなった場合はここに追記する）。
  static const Map<int, List<String>> businessTagsByIndex = {
    0: ['会社'],
    1: ['会社'],
    2: ['会社'],
    3: ['会社'],
    4: ['会社'],
    5: ['会社'],
    6: ['会社'],
    7: ['会社'],
    8: ['会社'],
    9: ['会社'],
  };

  /// `builtin_daily_<index>`のタブ。未知のindexは空配列。
  static List<String> forDailyIndex(int index) =>
      dailyTagsByIndex[index] ?? const [];

  /// `builtin_business_<index>`のタブ。未知のindexは空配列。
  static List<String> forBusinessIndex(int index) =>
      businessTagsByIndex[index] ?? const [];
}
