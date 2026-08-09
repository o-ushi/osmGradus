import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/services/rss_date_parser.dart';

void main() {
  test('"GMT"終端のRFC 1123形式（Anchor系フィード）を解析できる', () {
    final date = parseRssPubDate('Fri, 10 Jul 2026 15:31:43 GMT');
    expect(date, DateTime.utc(2026, 7, 10, 15, 31, 43));
  });

  test('"+0000"のような数値タイムゾーンオフセット（WordPress系フィード）も解析できる', () {
    // このフォーマットが原因で、Nihongo con Teppeiの全エピソードの日付が
    // nullになり、日付順の並べ替えが常に「新しい順」に固定される不具合があった。
    final date = parseRssPubDate('Fri, 10 Jul 2026 09:44:34 +0000');
    expect(date, DateTime.utc(2026, 7, 10, 9, 44, 34));
  });

  test('ゼロ以外の数値オフセットも正しくUTCへ変換する', () {
    final date = parseRssPubDate('Sat, 04 Jul 2026 14:00:58 +0900');
    expect(date, DateTime.utc(2026, 7, 4, 5, 0, 58));
  });

  test('異なる日付を持つ実際のフィード由来の文字列を正しい時系列順に並べ替えられる', () {
    // 実際にNihongo con Teppeiのフィードで確認された値。
    final raw = [
      'Fri, 10 Jul 2026 09:44:34 +0000',
      'Tue, 07 Jul 2026 22:42:56 +0000',
      'Sun, 05 Jul 2026 22:59:41 +0000',
      'Sat, 04 Jul 2026 14:00:58 +0000',
    ];
    final dates = raw.map(parseRssPubDate).toList();
    expect(dates.every((d) => d != null), isTrue);
    final sorted = [...dates]..sort((a, b) => b!.compareTo(a!));
    expect(sorted, dates); // 元々フィード順（新しい順）に並んでいることを確認
    expect(sorted.first!.isAfter(sorted.last!), isTrue);
  });

  test('不正な文字列にはnullを返す', () {
    expect(parseRssPubDate('not a date'), isNull);
    expect(parseRssPubDate(null), isNull);
    expect(parseRssPubDate(''), isNull);
  });
}
