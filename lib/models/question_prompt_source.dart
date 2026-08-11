/// 問題文（[QuestionPrompt]）の入手元。
enum QuestionPromptSource { builtIn, ai, manual, imported }

extension QuestionPromptSourceLabel on QuestionPromptSource {
  String get storageKey => switch (this) {
    QuestionPromptSource.builtIn => 'builtIn',
    QuestionPromptSource.ai => 'ai',
    QuestionPromptSource.manual => 'manual',
    QuestionPromptSource.imported => 'imported',
  };

  /// 不明な値は`imported`にフォールバックする（Step 1以前の取り込み済みお題は
  /// 入手経路を区別して記録していなかったため）。
  static QuestionPromptSource fromStorageKey(String? key) =>
      QuestionPromptSource.values.firstWhere(
        (source) => source.storageKey == key,
        orElse: () => QuestionPromptSource.imported,
      );
}
