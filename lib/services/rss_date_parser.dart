import 'package:http_parser/http_parser.dart';

const _rssMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// RFC 822形式の末尾のタイムゾーンとして"GMT"のみを扱う`+HHMM`/`-HHMM`のような
/// 数値オフセット（WordPress系のフィードでよく使われる）にも対応する。
final _rfc822Pattern = RegExp(
  r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
  r'(\d{2}):(\d{2}):(\d{2})\s*(GMT|UT|Z|[+-]\d{4})?$',
);

/// RSS/Atomの`<pubDate>`をパースする。osmPodの `FeedParserService` は複数の
/// 日付フォーマットを順に試すが、Flutterでは `http_parser` の
/// [parseHttpDate]（"GMT"終端のみ対応）を第一候補にしつつ、"+0000"のような
/// 数値オフセットのフィードにも対応できるよう自前でRFC 822を解析する。
DateTime? parseRssPubDate(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  try {
    return parseHttpDate(trimmed);
  } catch (_) {
    return _parseRfc822WithNumericOffset(trimmed) ?? DateTime.tryParse(trimmed);
  }
}

DateTime? _parseRfc822WithNumericOffset(String raw) {
  final match = _rfc822Pattern.firstMatch(raw);
  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final monthIndex = _rssMonthNames.indexOf(match.group(2)!);
  if (monthIndex == -1) return null;
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final offsetToken = match.group(7);

  var utc = DateTime.utc(year, monthIndex + 1, day, hour, minute, second);
  if (offsetToken != null &&
      offsetToken != 'GMT' &&
      offsetToken != 'UT' &&
      offsetToken != 'Z') {
    final sign = offsetToken.startsWith('-') ? -1 : 1;
    final offsetHours = int.parse(offsetToken.substring(1, 3));
    final offsetMinutes = int.parse(offsetToken.substring(3, 5));
    utc = utc.subtract(
      Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes),
    );
  }
  return utc;
}
