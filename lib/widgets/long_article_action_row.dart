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
/// - 登録単語なし → 枠だけ確保して非表示（レイアウトを揃える）
class LongArticleActionRow extends StatelessWidget {
  const LongArticleActionRow({
    super.key,
    required this.showEnrich,
    required this.onEnrich,
    this.onEnrichLongPress,
    required this.onVocabulary,
    this.onVocabularyLongPress,
    required this.onNext,
    this.languageCode = 'vi',
    this.enableActionHints = false,
  });

  final bool showEnrich;
  final VoidCallback? onEnrich;

  /// 「訳を付ける」の長押し。選び直し画面を経由せず直接Chrome AIへ進む
  /// 「近道」用。
  final VoidCallback? onEnrichLongPress;

  final VoidCallback onVocabulary;

  /// 「単語帳」の長押し。フロー本体に「＋」が無いため、使い方シート
  /// （[LayerHelpSheet]）を出す入口としてここに割り当てる。
  final VoidCallback? onVocabularyLongPress;

  final VoidCallback onNext;

  /// ツールチップ等の表示言語（`appSettings.language`）。
  final String languageCode;

  /// trueの間、3ボタンすべてにダブルタップの機能ヒント（Step 7の
  /// [ButtonActionHint]基盤）を付ける。ヒント文言は各ボタンの[tooltip]と
  /// 同じ文言をそのまま使う。
  final bool enableActionHints;

  @override
  Widget build(BuildContext context) {
    final lang = languageCode;
    return Row(
      children: [
        Expanded(
          child: TransportIconButton(
            icon: Icons.translate_rounded,
            tooltip: '訳を付ける'.tr(lang),
            visible: showEnrich,
            onTap: onEnrich,
            onLongPress: showEnrich ? onEnrichLongPress : null,
            borderless: true,
            hintTapText: enableActionHints ? '訳を付ける'.tr(lang) : null,
            hintLongPressText: enableActionHints && showEnrich
                ? 'ボタンヒント_訳付_長押し'.tr(lang)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TransportIconButton(
            icon: Icons.style_rounded,
            tooltip: '単語帳'.tr(lang),
            visible: true,
            onTap: onVocabulary,
            onLongPress: onVocabularyLongPress,
            borderless: true,
            hintTapText: enableActionHints ? '単語帳'.tr(lang) : null,
            hintLongPressText: enableActionHints && onVocabularyLongPress != null
                ? 'ボタンヒント_単語帳_長押し'.tr(lang)
                : null,
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
            hintTapText: enableActionHints ? '長文読解_次へヒント'.tr(lang) : null,
          ),
        ),
      ],
    );
  }
}
