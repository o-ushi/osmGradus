part of 'layer1_vocab_screen.dart';

/// 「＋」長押しの使い方シート。各行の`{{icon}}`は画面上の実アイコンに差し替える
/// （🇻🇳のみ、ボタン自体が絵文字ラベルのためテキストのまま）。
void showLayer1VocabUsageHelp(
  BuildContext context, {
  required String lang,
  required bool isKeyboardMode,
}) {
  if (isKeyboardMode) {
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅠ_語彙_キーボード使い方_回答言語'.tr(lang)),
        LayerHelpLine(
          text: 'レイヤーⅠ_語彙_キーボード使い方_レベル'.tr(lang),
          icon: Icons.keyboard_arrow_down,
        ),
        LayerHelpLine(
          text: 'レイヤーⅠ_語彙_キーボード使い方_サイコロ'.tr(lang),
          icon: Icons.casino,
        ),
        LayerHelpLine(text: 'レイヤーⅠ_語彙_キーボード使い方_回答'.tr(lang)),
        LayerHelpLine(
          text: 'レイヤーⅠ_語彙_キーボード使い方_ENTER中断'.tr(lang),
          indent: true,
        ),
        LayerHelpLine(
          text: 'レイヤーⅠ_語彙_キーボード使い方_再開'.tr(lang),
          icon: Icons.casino,
          indent: true,
        ),
        LayerHelpLine(
          text: 'レイヤーⅠ_語彙_キーボード使い方_送信'.tr(lang),
          icon: Icons.send_rounded,
        ),
        LayerHelpLine(text: 'レイヤーⅠ_語彙_キーボード使い方_貼り付け'.tr(lang)),
      ],
    );
    return;
  }
  LayerHelpSheet.show(
    context,
    title: '操作方法'.tr(lang),
    lines: [
      LayerHelpLine(
        text: 'レイヤーⅠ_語彙_使い方_録音モード'.tr(lang),
        icon: Icons.more_horiz_rounded,
      ),
      LayerHelpLine(
        text: 'レイヤーⅠ_語彙_使い方_表示切替'.tr(lang),
        icon: Icons.visibility_rounded,
      ),
      LayerHelpLine(text: 'レイヤーⅠ_語彙_使い方_回答言語'.tr(lang)),
      LayerHelpLine(text: 'レイヤーⅠ_語彙_使い方_レベル'.tr(lang)),
      LayerHelpLine(text: 'レイヤーⅠ_語彙_使い方_サイコロ'.tr(lang), icon: Icons.casino),
      LayerHelpLine(
        text: 'レイヤーⅠ_語彙_使い方_マイク'.tr(lang),
        icon: Icons.mic_rounded,
      ),
      LayerHelpLine(
        text: 'レイヤーⅠ_語彙_使い方_評価'.tr(lang),
        icon: Icons.send_rounded,
      ),
      LayerHelpLine(text: 'レイヤーⅠ_語彙_使い方_保存'.tr(lang)),
    ],
  );
}
