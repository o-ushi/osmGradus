/// Google検索（AIモード）へプロンプトを渡すURLの組み立て。
/// osmWashabeの`webSearchURL(prefilling:)`を移植した方式で、
/// [AIPromptTemplate]・[PronunciationExerciseAiPrompt]・
/// [PronunciationAiPromptTemplate]の3箇所が個別に持っていた
/// `Uri.https('www.google.co.jp', '/search', {...})`の組み立てを共通化したもの。
/// Chrome AI起動時のURLとプロンプトの組み合わせ。
typedef ChromeAiLaunchPlan = ({
  Uri url,
  String prompt,
  bool requiresClipboardPaste,
});

abstract final class GoogleAiSearch {
  /// osmWashabeの [GoogleAIModeLink.webSearchURL] と同じ目安。
  /// これを超えるときだけクリップボード貼り付けに切り替える。
  static const maxPrefillUrlLength = 7500;

  /// GoogleのAIモード検索（`udm=50`）に[query]を差し込んだURLを組み立てる。
  static Uri buildUrl(String query) {
    return Uri.https('www.google.co.jp', '/search', {
      'q': query,
      'udm': '50',
      'hl': 'ja',
      'gl': 'jp',
      'ie': 'UTF-8',
    });
  }

  /// 検索語句なしでAIモード画面だけ開く（長いプロンプトはクリップボードから貼る）。
  static Uri aiModeEntryUrl() {
    return Uri.https('www.google.co.jp', '/search', {
      'udm': '50',
      'hl': 'ja',
      'gl': 'jp',
    });
  }

  /// [prompt]をURLに載せられる長さならそのまま開き、長すぎる場合は
  /// AIモードの空画面を開いてクリップボード貼り付けを促す。
  static ChromeAiLaunchPlan buildLaunchPlan({
    required String prompt,
    required String lang,
  }) {
    final query = withLangPrefix(prompt, lang);
    final url = buildUrl(query);
    if (url.toString().length <= maxPrefillUrlLength) {
      return (
        url: url,
        prompt: prompt,
        requiresClipboardPaste: false,
      );
    }
    return (
      url: aiModeEntryUrl(),
      prompt: prompt,
      requiresClipboardPaste: true,
    );
  }

  /// [prompt]の先頭に「日本語で」という指定を付ける（既に付いていればそのまま）。
  /// 日本語のみで完結するプロンプト（お題生成・発音課題生成）向け。
  static String withJapanesePrefix(String prompt) =>
      withLangPrefix(prompt, 'ja');

  /// 表示言語に応じた接頭辞を付ける（評価プロンプト向け）。
  static String withLangPrefix(String prompt, String lang) {
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
