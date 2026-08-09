import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import 'ghost_pill.dart';

/// 「結論」「理由」「例示」（PREP法のラベル）の予約席。
/// 既定では`GhostPill`の非表示状態（背景色化・タップ無効）で配置しておく。
/// [exampleIcon]を指定すると、「例示」の枠をラベルではなくアイコン＋タップ
/// 操作のボタンに転用できる（レイヤーⅣ・Ⅴの「結果一覧」導線で使う、
/// [DiceActionRow]の`fortyFiveIcon`と同じ差し替え方式）。
/// [reasonLabel] / [onReasonTap] も同様に、「理由」枠を別ラベル＋タップ
/// 操作のボタンに転用できる（レイヤーⅡのGoogle検索導線で使う）。
/// [reasonIcon]を指定すると、[reasonLabel]より優先してアイコンボタンに
/// なる（レイヤーⅠの単語帳導線で使う、[exampleIcon]と同じ差し替え方式）。
class PrepLabelRow extends StatelessWidget {
  const PrepLabelRow({
    super.key,
    this.showConclusion = false,
    this.showReason = false,
    this.showExample = false,
    this.reasonLabel,
    this.reasonIcon,
    this.reasonTooltip,
    this.onReasonTap,
    this.reasonShowBorder = true,
    this.reasonHorizontalPadding = 18,
    this.reasonLabelFontSize = 18,
    this.exampleIcon,
    this.exampleTooltip,
    this.exampleActive = false,
    this.onExampleTap,
  });

  final bool showConclusion;
  final bool showReason;
  final bool showExample;

  /// nullなら「理由」。レイヤーⅡでは「🌐」など別ラベルに差し替える。
  final String? reasonLabel;
  final IconData? reasonIcon;
  final String? reasonTooltip;
  final VoidCallback? onReasonTap;

  /// レイヤーⅡの🌐など、枠なしで絵文字を大きくしたいときに使う。
  final bool reasonShowBorder;
  final double reasonHorizontalPadding;
  final double reasonLabelFontSize;

  final IconData? exampleIcon;
  final String? exampleTooltip;
  final bool exampleActive;
  final VoidCallback? onExampleTap;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Row(
      children: [
        Expanded(
          child: GhostPill(label: '結論'.tr(lang), visible: showConclusion),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: reasonIcon != null
              ? GhostPill(
                  icon: reasonIcon,
                  tooltip: reasonTooltip?.tr(lang),
                  visible: showReason,
                  onTap: onReasonTap,
                  showBorder: reasonShowBorder,
                  horizontalPadding: reasonHorizontalPadding,
                )
              : GhostPill(
                  label: reasonLabel ?? '理由'.tr(lang),
                  tooltip: reasonTooltip?.tr(lang),
                  visible: showReason,
                  onTap: onReasonTap,
                  showBorder: reasonShowBorder,
                  horizontalPadding: reasonHorizontalPadding,
                  labelFontSize: reasonLabelFontSize,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: exampleIcon != null
              ? GhostPill(
                  icon: exampleIcon,
                  tooltip: exampleTooltip?.tr(lang),
                  visible: showExample,
                  active: exampleActive,
                  activeFill: palette.accentColor,
                  activeForeground: palette.onAccent,
                  showBorder: false,
                  horizontalPadding: 0,
                  onTap: onExampleTap,
                )
              : GhostPill(label: '例示'.tr(lang), visible: showExample),
        ),
      ],
    );
  }
}
