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
/// 操作のボタンに転用できる。
/// [reasonIcon]を指定すると、[reasonLabel]より優先してアイコンボタンに
/// なる（レイヤーⅠの単語帳導線、レイヤーⅡの解答例＝Chrome AI往復導線、
/// レイヤーⅢのPREP「理由」欄で使う、[exampleIcon]と同じ差し替え方式）。
class PrepLabelRow extends StatelessWidget {
  const PrepLabelRow({
    super.key,
    this.showConclusion = false,
    this.conclusionLabel,
    this.conclusionIcon,
    this.conclusionTooltip,
    this.onConclusionTap,
    this.conclusionActive = false,
    this.conclusionHintTapText,
    this.conclusionHintLongPressText,
    this.showReason = false,
    this.showExample = false,
    this.reasonLabel,
    this.reasonIcon,
    this.reasonTooltip,
    this.onReasonTap,
    this.onReasonLongPress,
    this.reasonActive = false,
    this.reasonActiveFill,
    this.reasonActiveForeground,
    this.reasonShowBorder = true,
    this.reasonHorizontalPadding = 18,
    this.reasonLabelFontSize = 18,
    this.reasonHintTapText,
    this.reasonHintLongPressText,
    this.exampleIcon,
    this.exampleTooltip,
    this.exampleActive = false,
    this.exampleActiveFill,
    this.exampleActiveForeground,
    this.onExampleTap,
    this.exampleHintTapText,
    this.exampleHintLongPressText,
  });

  final bool showConclusion;

  /// nullなら「結論」。レイヤーⅠの問題文詳細では「理解」に差し替える
  /// （[reasonLabel]と同じ差し替え方式）。
  final String? conclusionLabel;

  /// 非nullの場合、[conclusionLabel]より優先して枠なし・余白ゼロの
  /// 大きいアイコンボタンにする（[exampleIcon]と同じ差し替え方式。
  /// レイヤーⅠの「理解」チェックで使う。文字ラベルだと3等分の枠に
  /// 収まらず小さくなるため）。
  final IconData? conclusionIcon;
  final String? conclusionTooltip;
  final VoidCallback? onConclusionTap;

  /// trueの間、[conclusionIcon]を橙色にして「実施済み」を示す（falseは白）。
  /// アイコン自体は差し替えず、色だけ変える（背景のピル自体は常に透明）。
  final bool conclusionActive;

  /// 非nullの場合、[conclusionIcon]モードのピルにダブルタップの機能ヒント
  /// （Step 7の[ButtonActionHint]基盤）を付ける（[GhostPill.hintTapText]）。
  final String? conclusionHintTapText;
  final String? conclusionHintLongPressText;

  final bool showReason;
  final bool showExample;

  /// nullなら「理由」。[reasonIcon]モード（レイヤーⅠ〜Ⅲ）では使わず、
  /// アイコンではなく文字ラベルで別名に差し替えたいときのための予約。
  final String? reasonLabel;
  final IconData? reasonIcon;
  final String? reasonTooltip;
  final VoidCallback? onReasonTap;

  /// 非nullの場合、[reasonIcon]モードのピルで長押しを別動作に使う
  /// （レイヤーⅡの解答例＝再取得など）。指定時は[reasonTooltip]の
  /// 長押し表示と競合するため[GhostPill]側がTooltipの長押し表示を譲る。
  final VoidCallback? onReasonLongPress;

  /// trueの間、[reasonIcon]を[reasonActiveForeground]（既定は橙）にして
  /// 「実施済み」を示す（[conclusionActive]と同じ、背景は透明のまま色だけ
  /// 変える方式。レイヤーⅢのPREP「理由」欄で使う）。
  final bool reasonActive;
  final Color? reasonActiveFill;
  final Color? reasonActiveForeground;

  /// レイヤーⅡの解答例アイコンなど、枠なしでアイコンを大きくしたいときに使う。
  final bool reasonShowBorder;
  final double reasonHorizontalPadding;
  final double reasonLabelFontSize;

  /// 非nullの場合、[reasonIcon]モードのピルにダブルタップの機能ヒント
  /// （[conclusionHintTapText]と同じStep 7の[ButtonActionHint]基盤）を付ける。
  final String? reasonHintTapText;
  final String? reasonHintLongPressText;

  final IconData? exampleIcon;
  final String? exampleTooltip;
  final bool exampleActive;

  /// [exampleActive]時の塗り・前景色。未指定なら既存どおり
  /// [AppPalette.accentColor]の塗りつぶし（レイヤーⅣ・Ⅴの「結果一覧」）。
  /// レイヤーⅢのPREP「具体例」欄では透明＋橙に差し替える。
  final Color? exampleActiveFill;
  final Color? exampleActiveForeground;
  final VoidCallback? onExampleTap;

  /// 非nullの場合、[exampleIcon]モードのピルにダブルタップの機能ヒント
  /// （[conclusionHintTapText]と同じStep 7の[ButtonActionHint]基盤）を付ける。
  final String? exampleHintTapText;
  final String? exampleHintLongPressText;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Row(
      children: [
        Expanded(
          child: conclusionIcon != null
              ? GhostPill(
                  // オン/オフで同じアイコン（未実施用の輪郭アイコン）のまま、
                  // 色だけ橙⇔白に切り替える（アイコンそのものを差し替えると
                  // オン/オフでサイズ感が変わって見えるため）。
                  icon: conclusionIcon,
                  tooltip: conclusionTooltip?.tr(lang),
                  visible: showConclusion,
                  active: conclusionActive,
                  activeFill: Colors.transparent,
                  activeForeground: Colors.orange,
                  showBorder: false,
                  horizontalPadding: 0,
                  onTap: onConclusionTap,
                  hintTapText: conclusionHintTapText?.tr(lang),
                  hintLongPressText: conclusionHintLongPressText?.tr(lang),
                )
              : GhostPill(
                  label: conclusionLabel ?? '結論'.tr(lang),
                  tooltip: conclusionTooltip?.tr(lang),
                  visible: showConclusion,
                  active: conclusionActive,
                  activeFill: palette.accentColor,
                  activeForeground: palette.onAccent,
                  onTap: onConclusionTap,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: reasonIcon != null
              ? GhostPill(
                  icon: reasonIcon,
                  tooltip: reasonTooltip?.tr(lang),
                  visible: showReason,
                  active: reasonActive,
                  activeFill: reasonActiveFill ?? Colors.transparent,
                  activeForeground: reasonActiveForeground ?? Colors.orange,
                  onTap: onReasonTap,
                  onLongPress: onReasonLongPress,
                  showBorder: reasonShowBorder,
                  horizontalPadding: reasonHorizontalPadding,
                  hintTapText: reasonHintTapText?.tr(lang),
                  hintLongPressText: reasonHintLongPressText?.tr(lang),
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
                  activeFill: exampleActiveFill ?? palette.accentColor,
                  activeForeground: exampleActiveForeground ?? palette.onAccent,
                  showBorder: false,
                  horizontalPadding: 0,
                  onTap: onExampleTap,
                  hintTapText: exampleHintTapText?.tr(lang),
                  hintLongPressText: exampleHintLongPressText?.tr(lang),
                )
              : GhostPill(label: '例示'.tr(lang), visible: showExample),
        ),
      ],
    );
  }
}
