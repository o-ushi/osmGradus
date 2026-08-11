import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import 'transport_icon_button.dart';

/// 「総評」への遷移バッジ。[GenkiTransportRow.diagnoseOverride]で、AI評価が
/// 届いたら紙飛行機の代わりに同じ枠へ差し込む（[TransportIconButton]、
/// borderless＝余白ゼロでアイコンを枠いっぱいに表示）。レイヤーⅤの
/// 「問題文一覧から選ぶ」（[Layer5Screen]のgradedPromptモード）で共有する。
class QuestionPromptSummaryBadge extends StatelessWidget {
  const QuestionPromptSummaryBadge({
    super.key,
    required this.onTap,
    this.enableActionHint = false,
  });

  final VoidCallback onTap;

  /// trueの間、ダブルタップの機能ヒント（Step 7の[ButtonActionHint]基盤）を
  /// 付ける。
  final bool enableActionHint;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return TransportIconButton(
      icon: Icons.fact_check_rounded,
      tooltip: '総評'.tr(lang),
      visible: true,
      onTap: onTap,
      highlighted: true,
      borderless: true,
      hintTapText: enableActionHint ? '総評'.tr(lang) : null,
    );
  }
}
