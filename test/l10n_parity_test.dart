import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/localization/gradus_l10n.dart';

/// [AppStrings]（osmWashabe由来）と[GradusL10n]（osmGradus固有）の二重辞書。
/// 同じキーが両方にあると「どちらを編集すべきか」が曖昧になるため検出する。
/// （実行時は Gradus が優先される。）
void main() {
  test('GradusL10n と AppStrings で同一キーを二重定義していない', () {
    final overlaps = <String>[];
    for (final lang in ['ja', 'en', 'vi']) {
      final gradus = GradusL10n.data[lang]!.keys.toSet();
      final base = AppStrings.debugBaseKeysFor(lang);
      for (final key in gradus.intersection(base)) {
        overlaps.add('$lang: $key');
      }
    }
    expect(
      overlaps,
      isEmpty,
      reason: '二重定義（Gradusへ寄せて AppStrings 側を削除すること）: $overlaps',
    );
  });

  test('GradusL10n の ja/en/vi でキー集合が一致する', () {
    final ja = GradusL10n.data['ja']!.keys.toSet();
    final en = GradusL10n.data['en']!.keys.toSet();
    final vi = GradusL10n.data['vi']!.keys.toSet();
    expect(
      en.difference(ja),
      isEmpty,
      reason: 'en にあって ja に無い: ${en.difference(ja)}',
    );
    expect(
      ja.difference(en),
      isEmpty,
      reason: 'ja にあって en に無い: ${ja.difference(en)}',
    );
    expect(
      vi.difference(ja),
      isEmpty,
      reason: 'vi にあって ja に無い: ${vi.difference(ja)}',
    );
    expect(
      ja.difference(vi),
      isEmpty,
      reason: 'ja にあって vi に無い: ${ja.difference(vi)}',
    );
  });

  test('Gradus にあるキーは AppStrings.text でも Gradus の文言が返る', () {
    for (final lang in ['ja', 'en', 'vi']) {
      final map = GradusL10n.data[lang]!;
      for (final entry in map.entries) {
        expect(
          AppStrings.text(entry.key, lang),
          entry.value,
          reason: 'Gradus優先が崩れている: $lang / ${entry.key}',
        );
      }
    }
  });
}
