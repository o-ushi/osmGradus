import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/practice_timer_models.dart';
import '../theme/app_colors.dart';
import 'ghost_pill.dart';

/// osmGenkiの発話時間セレクター（∞/30/45/60）と同じ見た目のピル型ボタン列。
/// 「45」「60」「15+60」はスピーチ時間のプリセットで、レイヤーごとに
/// 表示/非表示を切り替えられる。visible時は[onPresetTap]が渡っていれば
/// タップで選択でき、[selectedOption]と一致するピルが青色でハイライトされる
/// （レイヤーⅢのタイマープリセット選択で使う）。
/// 非表示時もレイアウト上の枠は確保したまま背景色に同化させるだけに
/// とどめる（`if` で丸ごと外すと「＋」の位置がレイヤーごとにズレるため）。
/// 「＋」は既定で右端に固定表示し、お題の取り込み導線として使うが、
/// [showAdd]をfalseにすると他のプリセットピルと同様にゴースト化できる。
/// レイヤーⅡ・Ⅲ・Ⅳとも「＋」タップは「AIで追加/自分で追加」選択シート
/// （`TopicAddChoiceSheet`）への導線、長押しは操作方法シート
/// （履歴は[PrepLabelRow]側）。
class DiceActionRow extends StatelessWidget {
  const DiceActionRow({
    super.key,
    this.show45 = false,
    this.show60 = false,
    this.show15Plus60 = false,
    this.showAdd = true,
    this.addIcon = Icons.add,
    this.addTooltip = 'お題の取り込み',
    this.selectedOption,
    this.onPresetTap,
    required this.onAddTap,
    this.onAddLongPress,
    this.addHintTapText,
    this.addHintLongPressText,
    this.fortyFiveIcon,
    this.fortyFiveLabel,
    this.onFortyFiveTap,
    this.fortyFiveTooltip,
    this.fortyFiveActive = false,
    this.fortyFiveActiveFill,
    this.fortyFiveActiveForeground,
    this.fortyFiveShowBorder = true,
    this.fortyFiveHorizontalPadding = 18,
    this.fortyFiveIconSize = 24,
    this.fortyFiveLabelFontSize = 18,
    this.fortyFiveHintTapText,
    this.sixtyLabel,
    this.sixtyIcon,
    this.sixtyActive = false,
    this.onSixtyTap,
    this.sixtyTooltip,
    this.sixtyShowBorder = true,
    this.sixtyHorizontalPadding = 18,
    this.sixtyLabelFontSize = 18,
    this.sixtyIconSize = 24,
    this.sixtyHintTapText,
    this.fifteenSixtyLabel,
    this.fifteenSixtyIcon,
    this.onFifteenSixtyTap,
    this.onFifteenSixtyLongPress,
    this.fifteenSixtyTooltip,
    this.fifteenSixtyShowBorder = true,
    this.fifteenSixtyHorizontalPadding = 18,
    this.fifteenSixtyLabelFontSize = 18,
    this.fifteenSixtyIconSize = 24,
    this.fifteenSixtyHintTapText,
    this.fifteenSixtyHintLongPressText,
  });

  final bool show45;
  final bool show60;
  final bool show15Plus60;
  final bool showAdd;
  final IconData addIcon;
  final String addTooltip;

  /// 現在選択中のプリセット（ハイライト表示に使う）。nullなら選択なし扱い。
  final NormalTimerOption? selectedOption;

  /// nullの場合、プリセットピルは表示されていてもタップに反応しない
  /// （タップ機能がまだ必要ないレイヤーで使う）。
  final ValueChanged<NormalTimerOption>? onPresetTap;
  final VoidCallback onAddTap;

  /// 非nullの場合、「＋」の長押しで呼ぶ（レイヤーの使い方シートを開く導線）。
  final VoidCallback? onAddLongPress;

  /// 非nullの場合、「＋」にダブルタップの機能ヒント（Step 7の
  /// [ButtonActionHint]基盤、[GhostPill.hintTapText]と同じ）を付ける。
  final String? addHintTapText;
  final String? addHintLongPressText;

  /// 非nullの場合、「45」ピルをタイマープリセットではなく単なる
  /// アイコンボタンとして描画する（レイヤーⅤの断続/連続モード切り替え）。
  /// [onFortyFiveTap]と併せて指定する。
  final IconData? fortyFiveIcon;
  final String? fortyFiveLabel;
  final VoidCallback? onFortyFiveTap;
  final String? fortyFiveTooltip;
  final bool fortyFiveActive;

  /// active時の塗り色・前景色。未指定なら「＋」と同じ[AppPalette.accentColor]/
  /// [AppPalette.onAccent]を使う（レイヤーⅤの録音モードごとに色分けする際に使う、
  /// [GhostPill.activeFill]/[GhostPill.activeForeground]と同じ差し替え方式）。
  final Color? fortyFiveActiveFill;
  final Color? fortyFiveActiveForeground;

  /// アイコンを枠なし・大きくしたいとき用（[sixtyShowBorder]と同じ差し替え方式）。
  final bool fortyFiveShowBorder;
  final double fortyFiveHorizontalPadding;
  final double fortyFiveIconSize;
  final double fortyFiveLabelFontSize;

  /// 非nullの場合、[fortyFiveIcon]モード（タイマープリセットからの転用時）に
  /// ダブルタップの機能ヒント（[GhostPill.hintTapText]）を付ける。タイマー
  /// プリセットとして使うとき（[fortyFiveIcon]がnull）は連打する操作系
  /// ボタンのため対象外（このフィールドは無視される）。
  final String? fortyFiveHintTapText;

  /// 非nullの場合、「60」ピルをスピーチ時間プリセットではなく、単なる
  /// ラベル＋タップ操作のボタンとして描画する（[fortyFiveIcon]と同じ差し替え
  /// 方式。レイヤーⅠの単語テストで、回答言語トグル🇻🇳/🇺🇸/🇯🇵に使う）。
  /// [onSixtyTap]と併せて指定する。
  final String? sixtyLabel;
  final VoidCallback? onSixtyTap;
  final String? sixtyTooltip;

  /// 国旗など枠なしで絵文字を大きくしたいとき用（[PrepLabelRow.reasonShowBorder]
  /// と同じ差し替え方式）。
  final bool sixtyShowBorder;
  final double sixtyHorizontalPadding;
  final double sixtyLabelFontSize;

  /// 非nullの場合、「60」ピルを[sixtyLabel]でもなくアイコンボタンとして描画する
  /// （[fortyFiveIcon]と同じ差し替え方式。レイヤーⅠの単語テストで、問題の
  /// 表示/非表示トグルに使う）。[sixtyIcon]は[sixtyLabel]より優先される。
  final IconData? sixtyIcon;
  final bool sixtyActive;
  final double sixtyIconSize;

  /// 非nullの場合、[sixtyLabel]/[sixtyIcon]モード（タイマープリセットからの
  /// 転用時）にダブルタップの機能ヒントを付ける（[fortyFiveHintTapText]と
  /// 同じ考え方）。
  final String? sixtyHintTapText;

  /// 非nullの場合、「15+60」ピルをタイマープリセットではなく、単なるラベル＋
  /// タップ操作のボタンとして描画する（[sixtyLabel]と同じ差し替え方式。
  /// レイヤーⅠの単語テストで、回答言語トグル🇻🇳/🇺🇸/🇯🇵に使う）。
  /// [onFifteenSixtyTap]と併せて指定する。
  final String? fifteenSixtyLabel;
  final IconData? fifteenSixtyIcon;
  final VoidCallback? onFifteenSixtyTap;
  final VoidCallback? onFifteenSixtyLongPress;
  final String? fifteenSixtyTooltip;
  final bool fifteenSixtyShowBorder;
  final double fifteenSixtyHorizontalPadding;
  final double fifteenSixtyLabelFontSize;
  final double fifteenSixtyIconSize;

  /// 非nullの場合、[fifteenSixtyLabel]/[fifteenSixtyIcon]モード
  /// （タイマープリセットからの転用時）にダブルタップの機能ヒントを付ける
  /// （[fortyFiveHintTapText]と同じ考え方）。
  final String? fifteenSixtyHintTapText;
  final String? fifteenSixtyHintLongPressText;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Row(
      children: [
        Expanded(
          child: fortyFiveIcon != null
              ? GhostPill(
                  icon: fortyFiveIcon,
                  visible: show45,
                  active: fortyFiveActive,
                  activeFill: fortyFiveActiveFill ?? palette.accentColor,
                  activeForeground: fortyFiveActiveForeground,
                  showBorder: fortyFiveShowBorder,
                  horizontalPadding: fortyFiveHorizontalPadding,
                  iconSize: fortyFiveIconSize,
                  onTap: onFortyFiveTap,
                  tooltip: fortyFiveTooltip?.tr(lang),
                  hintTapText: fortyFiveHintTapText?.tr(lang),
                )
              : GhostPill(
                  label: fortyFiveLabel ?? '45',
                  tooltip: fortyFiveLabel != null
                      ? fortyFiveTooltip?.tr(lang)
                      : null,
                  visible: show45,
                  active: fortyFiveLabel != null
                      ? fortyFiveActive
                      : selectedOption == NormalTimerOption.sec45,
                  activeFill: fortyFiveActiveFill ?? palette.accentColor,
                  activeForeground: fortyFiveActiveForeground,
                  showBorder: fortyFiveLabel != null
                      ? fortyFiveShowBorder
                      : true,
                  horizontalPadding: fortyFiveLabel != null
                      ? fortyFiveHorizontalPadding
                      : 18,
                  labelFontSize: fortyFiveLabel != null
                      ? fortyFiveLabelFontSize
                      : 18,
                  onTap: fortyFiveLabel != null
                      ? onFortyFiveTap
                      : (onPresetTap == null
                            ? null
                            : () => onPresetTap!(NormalTimerOption.sec45)),
                  hintTapText: fortyFiveLabel != null
                      ? fortyFiveHintTapText?.tr(lang)
                      : null,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: sixtyIcon != null
              ? GhostPill(
                  icon: sixtyIcon,
                  visible: show60,
                  active: sixtyActive,
                  activeFill: palette.accentColor,
                  activeForeground: palette.onAccent,
                  showBorder: sixtyShowBorder,
                  horizontalPadding: sixtyHorizontalPadding,
                  iconSize: sixtyIconSize,
                  onTap: onSixtyTap,
                  tooltip: sixtyTooltip?.tr(lang),
                  hintTapText: sixtyHintTapText?.tr(lang),
                )
              : GhostPill(
                  label: sixtyLabel ?? '60',
                  tooltip: sixtyLabel != null ? sixtyTooltip?.tr(lang) : null,
                  visible: show60,
                  active:
                      sixtyLabel == null &&
                      selectedOption == NormalTimerOption.sec60,
                  activeFill: sixtyLabel == null ? palette.accentColor : null,
                  activeForeground: sixtyLabel == null
                      ? palette.onAccent
                      : null,
                  showBorder: sixtyLabel != null ? sixtyShowBorder : true,
                  horizontalPadding: sixtyLabel != null
                      ? sixtyHorizontalPadding
                      : 18,
                  labelFontSize: sixtyLabel != null ? sixtyLabelFontSize : 18,
                  onTap: sixtyLabel != null
                      ? onSixtyTap
                      : (onPresetTap == null
                            ? null
                            : () => onPresetTap!(NormalTimerOption.sec60)),
                  hintTapText: sixtyLabel != null
                      ? sixtyHintTapText?.tr(lang)
                      : null,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: fifteenSixtyIcon != null
              ? GhostPill(
                  icon: fifteenSixtyIcon,
                  visible: show15Plus60,
                  showBorder: fifteenSixtyShowBorder,
                  horizontalPadding: fifteenSixtyHorizontalPadding,
                  iconSize: fifteenSixtyIconSize,
                  onTap: onFifteenSixtyTap,
                  onLongPress: onFifteenSixtyLongPress,
                  tooltip: fifteenSixtyTooltip?.tr(lang),
                  hintTapText: fifteenSixtyHintTapText?.tr(lang),
                  hintLongPressText: fifteenSixtyHintLongPressText?.tr(lang),
                )
              : GhostPill(
                  label: fifteenSixtyLabel ?? '15+60',
                  tooltip: fifteenSixtyLabel != null
                      ? fifteenSixtyTooltip?.tr(lang)
                      : null,
                  visible: show15Plus60,
                  active:
                      fifteenSixtyLabel == null &&
                      selectedOption == NormalTimerOption.prep15speaking60,
                  activeFill: fifteenSixtyLabel == null
                      ? palette.accentColor
                      : null,
                  activeForeground: fifteenSixtyLabel == null
                      ? palette.onAccent
                      : null,
                  showBorder: fifteenSixtyLabel != null
                      ? fifteenSixtyShowBorder
                      : true,
                  // 文字数が多いため、他のピルより左右パディングを狭くして
                  // FittedBoxの縮小を緩和する。
                  horizontalPadding: fifteenSixtyLabel != null
                      ? fifteenSixtyHorizontalPadding
                      : 6,
                  labelFontSize: fifteenSixtyLabel != null
                      ? fifteenSixtyLabelFontSize
                      : 18,
                  onTap: fifteenSixtyLabel != null
                      ? onFifteenSixtyTap
                      : (onPresetTap == null
                            ? null
                            : () => onPresetTap!(
                                NormalTimerOption.prep15speaking60,
                              )),
                  onLongPress: fifteenSixtyLabel != null
                      ? onFifteenSixtyLongPress
                      : null,
                  hintTapText: fifteenSixtyLabel != null
                      ? fifteenSixtyHintTapText?.tr(lang)
                      : null,
                  hintLongPressText: fifteenSixtyLabel != null
                      ? fifteenSixtyHintLongPressText?.tr(lang)
                      : null,
                ),
        ),
        const SizedBox(width: 8),
        // 「＋」だけはExpandedにせず内容サイズのまま、常に行の右端に固定する。
        SizedBox(
          width: 56,
          child: GhostPill(
            icon: addIcon,
            onTap: onAddTap,
            onLongPress: onAddLongPress,
            tooltip: addTooltip.tr(lang),
            visible: showAdd,
            showBorder: false,
            horizontalPadding: 0,
            hintTapText: addHintTapText?.tr(lang),
            hintLongPressText: addHintLongPressText?.tr(lang),
          ),
        ),
      ],
    );
  }
}
