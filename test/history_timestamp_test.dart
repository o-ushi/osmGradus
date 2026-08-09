import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/utils/history_timestamp.dart';

void main() {
  final dt = DateTime(2026, 7, 29, 5, 13);

  test('formatLocalizedDate follows language-specific order', () {
    expect(formatLocalizedDate(dt, 'ja'), '2026/7/29');
    expect(formatLocalizedDate(dt, 'en'), '7/29/2026');
    expect(formatLocalizedDate(dt, 'vi'), '29/7/2026');
  });

  test('formatHistoryTimestamp follows language-specific month/day order', () {
    expect(formatHistoryTimestamp(dt, languageCode: 'ja'), '7/29 05:13');
    expect(formatHistoryTimestamp(dt, languageCode: 'en'), '7/29 05:13');
    expect(formatHistoryTimestamp(dt, languageCode: 'vi'), '29/7 05:13');
  });

  test('formatHistoryDetailTimestamp includes year in language order', () {
    expect(
      formatHistoryDetailTimestamp(dt, languageCode: 'ja'),
      '2026/7/29 05:13',
    );
    expect(
      formatHistoryDetailTimestamp(dt, languageCode: 'en'),
      '7/29/2026 05:13',
    );
    expect(
      formatHistoryDetailTimestamp(dt, languageCode: 'vi'),
      '29/7/2026 05:13',
    );
  });
}
