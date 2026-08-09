import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import 'transport_icon_button.dart';

/// 長文読解フローの読解画面の操作バー。[GenkiTransportRow]
/// （レイヤーⅡ〜Ⅴの再生・リセット・送信ボタン）と同じ枠
/// （[TransportIconButton]、余白ゼロ・背景と枠線は透明・アイコンを
/// 目一杯大きく表示）を、左スロット／単語帳／次へに差し替えて使う。
///
/// 左スロット:
/// - 登録単語あり →「訳を付ける」（タップ＝選び直し、長押し＝自動送信）
/// - 登録単語なし →「隠す」（単語帳ハイライトの表示切替）
class LongArticleActionRow extends StatelessWidget {
  const LongArticleActionRow({
    super.key,
    required this.showEnrich,
    required this.onEnrich,
    this.onEnrichLongPress,
    required this.highlightsVisible,
    required this.onToggleHighlights,
    required this.onVocabulary,
    required this.onNext,
    this.languageCode = 'vi',
  });

  final bool showEnrich;
  final VoidCallback? onEnrich;

  /// 「訳を付ける」の長押し。選び直し画面を経由せず直接Chrome AIへ進む
  /// 「近道」用。
  final VoidCallback? onEnrichLongPress;

  /// 単語帳ハイライトの表示状態（true=表示）。
  final bool highlightsVisible;
  final VoidCallback onToggleHighlights;
  final VoidCallback onVocabulary;
  final VoidCallback onNext;

  /// ツールチップ等の表示言語（`appSettings.language`）。
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final lang = languageCode;
    return Row(
      children: [
        Expanded(
          child: showEnrich
              ? TransportIconButton(
                  icon: Icons.translate_rounded,
                  tooltip: '訳を付ける'.tr(lang),
                  visible: true,
                  onTap: onEnrich,
                  onLongPress: onEnrichLongPress,
                  borderless: true,
                )
              : TransportIconButton(
                  icon: highlightsVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  tooltip: (highlightsVisible ? '隠す' : '表示').tr(lang),
                  visible: true,
                  onTap: onToggleHighlights,
                  borderless: true,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TransportIconButton(
            icon: Icons.style_rounded,
            tooltip: '単語帳'.tr(lang),
            visible: true,
            onTap: onVocabulary,
            borderless: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TransportIconButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: '次へ'.tr(lang),
            visible: true,
            onTap: onNext,
            borderless: true,
          ),
        ),
      ],
    );
  }
}
