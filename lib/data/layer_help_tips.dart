/// ヘルプ画面と各レイヤー「＋」使い方シートで共有する tip キーの単一ソース。
abstract final class LayerHelpTips {
  static const layerTitleKeys = [
    'help.gradus.layer1.title',
    'help.gradus.layer2.title',
    'help.gradus.layer3.title',
    'help.gradus.layer4.title',
    'help.gradus.layer5.title',
  ];

  static const layers = [
    LayerHelpTipSpec(
      titleKey: 'help.gradus.layer1.title',
      summaryKey: 'help.gradus.layer1.summary',
      tipKeys: [
        'help.gradus.layer1.tip1',
        'help.gradus.layer1.tip2',
        'help.gradus.layer1.tip3',
        'help.gradus.layer1.tip4',
        'help.gradus.layer1.tip5',
      ],
    ),
    LayerHelpTipSpec(
      titleKey: 'help.gradus.layer2.title',
      summaryKey: 'help.gradus.layer2.summary',
      tipKeys: [
        'help.gradus.layer2.tip1',
        'help.gradus.layer2.tip2',
        'help.gradus.layer2.tip3',
        'help.gradus.layer2.tip4',
      ],
    ),
    LayerHelpTipSpec(
      titleKey: 'help.gradus.layer3.title',
      summaryKey: 'help.gradus.layer3.summary',
      tipKeys: [
        'help.gradus.layer3.tip1',
        'help.gradus.layer3.tip2',
        'help.gradus.layer3.tip3',
        'help.gradus.layer3.tip4',
      ],
    ),
    LayerHelpTipSpec(
      titleKey: 'help.gradus.layer4.title',
      summaryKey: 'help.gradus.layer4.summary',
      tipKeys: [
        'help.gradus.layer4.tip1',
        'help.gradus.layer4.tip2',
        'help.gradus.layer4.tip3',
      ],
    ),
    LayerHelpTipSpec(
      titleKey: 'help.gradus.layer5.title',
      summaryKey: 'help.gradus.layer5.summary',
      tipKeys: [
        'help.gradus.layer5.tip1',
        'help.gradus.layer5.tip2',
        'help.gradus.layer5.tip3',
        'help.gradus.layer5.tip4',
        'help.gradus.layer5.tip5',
      ],
    ),
  ];

  /// [layerIndex] は 0..4（レイヤーⅠ〜Ⅴ）。
  static List<String> tipKeysForLayer(int layerIndex) =>
      layers[layerIndex].tipKeys;

  static LayerHelpTipSpec specForLayer(int layerIndex) => layers[layerIndex];
}

/// 1レイヤー分のヘルプ見出し・要約・箇条書きキー。
class LayerHelpTipSpec {
  const LayerHelpTipSpec({
    required this.titleKey,
    required this.summaryKey,
    required this.tipKeys,
  });

  final String titleKey;
  final String summaryKey;
  final List<String> tipKeys;
}
