import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import 'transport_icon_button.dart';

/// 「結論/理由/例示」（[PrepStageRow]の`_PrepPill`）と同じ形・サイズ
/// （高さ56、角丸28の枠線ボタン）に、アイコンだけを乗せて3等分＋12px間隔で
/// 並べたボタン列。
/// レイヤーⅡでは`show*`をfalseのまま使い、背景色に同化させて実質非表示・
/// タップ無効の予約席にする。レイヤーⅣでは`show*`をtrueにし、
/// `onPlay`/`onReset`/`onDiagnose`を渡して実際の録音操作に使う。
/// レイヤーⅤでは「送信（Chrome AI）」→「貼り付け」の2段階表示（osmGenki流用）。
class GenkiTransportRow extends StatelessWidget {
  const GenkiTransportRow({
    super.key,
    this.showPlay = false,
    this.showReset = false,
    this.showDiagnose = false,
    this.playing = false,
    this.playHasData = false,
    this.diagnoseHighlighted = false,
    this.diagnoseAwaitingPaste = false,
    this.onPlay,
    this.onReset,
    this.onDiagnose,
    this.languageCode = 'vi',
  });

  final bool showPlay;
  final bool showReset;
  final bool showDiagnose;

  /// 「再生」ボタンが現在再生中かどうか（osmGenkiの「聴き直す」ボタンと同じ、
  /// タップで再生⇄一時停止をトグルする動線用）。trueの間はアイコンが
  /// ▶️→⏸️に変わる。
  final bool playing;

  /// 再生できる直近の録音があるかどうか。trueの間は「＋」ピル
  /// （評価結果・発音チェック結果一覧への導線）と同じ、青地に白アイコンで
  /// 強調する（データが無ければ透明な枠線ボタンのまま）。
  final bool playHasData;

  /// 「送信」ボタンを青地で強調する（録音データあり・貼り付け待ちでない）。
  final bool diagnoseHighlighted;

  /// Chrome AI から戻ったあとの「貼り付け」待ち。緑地＋ペーストアイコン。
  final bool diagnoseAwaitingPaste;

  final VoidCallback? onPlay;
  final VoidCallback? onReset;
  final VoidCallback? onDiagnose;

  /// ツールチップ等の表示言語（`appSettings.language`）。
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final lang = languageCode;
    return Row(
      children: [
        Expanded(
          child: TransportIconButton(
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: playing ? '一時停止'.tr(lang) : '再生'.tr(lang),
            visible: showPlay,
            onTap: onPlay,
            highlighted: playHasData,
            // 再生できる録音がまだ無いときはグレーアウトしてタップも無効にする。
            enabled: playHasData,
            borderless: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TransportIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'リセット'.tr(lang),
            visible: showReset,
            onTap: onReset,
            borderless: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TransportIconButton(
            icon: diagnoseAwaitingPaste
                ? Icons.content_paste_go_rounded
                : Icons.send_rounded,
            tooltip: diagnoseAwaitingPaste ? '貼り付け'.tr(lang) : '送信'.tr(lang),
            visible: showDiagnose,
            onTap: onDiagnose,
            highlighted: diagnoseHighlighted || diagnoseAwaitingPaste,
            highlightColor: diagnoseAwaitingPaste ? kPasteReadyColor : null,
          ),
        ),
      ],
    );
  }
}
