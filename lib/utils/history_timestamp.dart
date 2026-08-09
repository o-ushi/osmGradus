String _two(int n) => n.toString().padLeft(2, '0');

/// 言語ごとの日付表記順。
/// - ja: 年/月/日
/// - en: 月/日/年
/// - vi: 日/月/年
String formatLocalizedDate(DateTime dt, String languageCode) {
  final y = dt.year;
  final m = dt.month;
  final d = dt.day;
  return switch (languageCode) {
    'en' => '$m/$d/$y',
    'vi' => '$d/$m/$y',
    _ => '$y/$m/$d',
  };
}

/// 履歴一覧で使う共通の日時表示（言語ごとの月日 + 時:分）。
/// 年なしの短い表記なので、ja/en は月/日、vi は日/月。
String formatHistoryTimestamp(DateTime dt, {String languageCode = 'ja'}) {
  final m = dt.month;
  final d = dt.day;
  final time = '${_two(dt.hour)}:${_two(dt.minute)}';
  final date = switch (languageCode) {
    'vi' => '$d/$m',
    _ => '$m/$d',
  };
  return '$date $time';
}

/// 履歴詳細で使う共通の日時表示（言語ごとの年月日 + 時:分）。
String formatHistoryDetailTimestamp(DateTime dt, {String languageCode = 'ja'}) {
  return '${formatLocalizedDate(dt, languageCode)} ${_two(dt.hour)}:${_two(dt.minute)}';
}
