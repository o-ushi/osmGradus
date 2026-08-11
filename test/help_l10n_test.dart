import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/layer_help_tips.dart';
import 'package:osm_gradus/localization/gradus_l10n.dart';

/// ヘルプ画面（[HelpScreen]）が参照するキーは、機能追加のたびに増える。
/// 追加時に一部の言語だけ埋め忘れると、その言語ではキー文字列がそのまま
/// 画面に出てしまう。ここでは「ヘルプ文言が3言語すべてに存在し空でない」
/// ことと「画面が参照する具体キーが実在する」ことを機械的に検査する。
void main() {
  const langs = ['ja', 'en', 'vi'];

  Map<String, String> mapFor(String lang) {
    final map = GradusL10n.data[lang];
    expect(map, isNotNull, reason: '言語 $lang の辞書が無い');
    return map!;
  }

  test('すべての help.gradus.* キーが ja/en/vi に存在し、空でない', () {
    // どれか1言語にでも存在する help キーを母集合にし、全言語での欠落・空を検出する。
    final allHelpKeys = <String>{
      for (final lang in langs)
        ...mapFor(lang).keys.where((k) => k.startsWith('help.gradus.')),
    };
    expect(allHelpKeys, isNotEmpty);

    final missing = <String>[];
    final blank = <String>[];
    for (final key in allHelpKeys) {
      for (final lang in langs) {
        final value = mapFor(lang)[key];
        if (value == null) {
          missing.add('$lang: $key');
        } else if (value.trim().isEmpty) {
          blank.add('$lang: $key');
        }
      }
    }

    expect(missing, isEmpty, reason: 'ヘルプ文言が欠落している: $missing');
    expect(blank, isEmpty, reason: 'ヘルプ文言が空: $blank');
  });

  test('HelpScreen と LayerHelpTips が参照する全キーが3言語に実在する', () {
    // help_screen.dart の build()／_extraSections が参照するキーの契約。
    // 画面側に手を入れたらこの一覧も更新する（コードにしか無いキーが
    // どの言語にも無い、という取りこぼしを防ぐための明示リスト）。
    const referenced = <String>[
      'help.gradus.title',
      'help.gradus.subtitle',
      'help.gradus.sections.layers',
      'help.gradus.sections.more',
      'help.gradus.overview.title',
      'help.gradus.overview.summary',
      'help.gradus.overview.tip1',
      'help.gradus.overview.tip2',
      'help.gradus.overview.tip3',
      'help.gradus.overview.tip4',
      // _extraSections（dashboard / vocabulary / transcript / backup / settings / gesture）
      'help.gradus.dashboard.title',
      'help.gradus.dashboard.summary',
      'help.gradus.dashboard.tip1',
      'help.gradus.dashboard.tip2',
      'help.gradus.dashboard.tip3',
      'help.gradus.dashboard.tip4',
      'help.gradus.vocabulary.title',
      'help.gradus.vocabulary.summary',
      'help.gradus.vocabulary.tip1',
      'help.gradus.vocabulary.tip2',
      'help.gradus.vocabulary.tip3',
      'help.gradus.vocabulary.tip4',
      'help.gradus.transcript.title',
      'help.gradus.transcript.summary',
      'help.gradus.transcript.tip1',
      'help.gradus.transcript.tip2',
      'help.gradus.transcript.tip3',
      'help.gradus.backup.title',
      'help.gradus.backup.summary',
      'help.gradus.backup.tip1',
      'help.gradus.backup.tip2',
      'help.gradus.backup.tip3',
      'help.gradus.backup.tip4',
      'help.gradus.settings.title',
      'help.gradus.settings.summary',
      'help.gradus.settings.tip1',
      'help.gradus.settings.tip2',
      'help.gradus.settings.tip3',
      'help.gradus.settings.tip4',
      'help.gradus.gesture.title',
      'help.gradus.gesture.summary',
      'help.gradus.gesture.tip1',
      'help.gradus.gesture.tip2',
      'help.gradus.gesture.tip3',
    ];

    // レイヤーⅠ〜Ⅴのヒント（＋使い方シートと共有）も同じ辞書から引く。
    final layerKeys = <String>{
      ...LayerHelpTips.layerTitleKeys,
      for (final spec in LayerHelpTips.layers) ...[
        spec.titleKey,
        spec.summaryKey,
        ...spec.tipKeys,
      ],
    };

    final expectedKeys = {...referenced, ...layerKeys};

    final missing = <String>[];
    for (final key in expectedKeys) {
      for (final lang in langs) {
        final value = mapFor(lang)[key];
        if (value == null || value.trim().isEmpty) {
          missing.add('$lang: $key');
        }
      }
    }

    expect(missing, isEmpty, reason: '参照キーが未定義または空: $missing');
  });
}
