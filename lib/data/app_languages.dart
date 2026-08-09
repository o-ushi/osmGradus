/// アプリで選択できる表示言語（言語コード, 表示名, 国旗絵文字）。
/// osmWashabeはvi/ja/enの順だったが、osmGradusでは英語→日本語→
/// ベトナム語の順で表示する（[TtsSettingsScreen]・[LanguageFlagButton]で共通）。
const appLanguages = [
  ('en', 'English', '🇺🇸'),
  ('ja', '日本語', '🇯🇵'),
  ('vi', 'Tiếng Việt', '🇻🇳'),
];
