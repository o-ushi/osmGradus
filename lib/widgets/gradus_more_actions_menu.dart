import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';

/// 起動画面下部「…」から開く、成績証明証・エクスポート・インポート・設定・
/// ヘルプのアイコン一覧メニュー（osmGenkiの `GenkiMoreActionsMenu` と同じ
/// 配置方式）。
///
/// アイコン自体は26pxのまま、ボタン枠と間隔だけ詰めて
/// iPhone SE（幅320）でも横スクロールなしで収まるようにしている。
class GradusMoreActionsMenu extends StatelessWidget {
  const GradusMoreActionsMenu({
    super.key,
    required this.languageCode,
    required this.onTranscript,
    required this.onExport,
    required this.onImport,
    required this.onSettings,
    required this.onHelp,
    this.maxWidth,
  });

  final String languageCode;
  final VoidCallback onTranscript;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  /// 画面幅に収まらないとき、この幅に収めて横スクロールする（極端に狭い端末向け）。
  final double? maxWidth;

  static const _itemCount = 5;
  static const _buttonSize = 40.0;
  static const _iconGlyphSize = 26.0;
  static const _iconGap = 6.0;
  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 8.0;

  /// 自然幅（ボタン数×枠サイズ＋間隔＋左右パディング）。
  static const double intrinsicWidth =
      _horizontalPadding * 2 +
      _itemCount * _buttonSize +
      (_itemCount - 1) * _iconGap;

  /// [availableWidth]に収まる表示幅（狭い端末では画面内に収める）。
  static double widthFor(double availableWidth) {
    if (availableWidth <= 0) return intrinsicWidth;
    return intrinsicWidth < availableWidth ? intrinsicWidth : availableWidth;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final iconFg = palette.textOnCardPrimary;
    final iconBg = palette.textOnCardSecondary.withValues(alpha: 0.08);
    final iconBorder = palette.cardBorder;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _itemCount; i++) ...[
            if (i > 0) const SizedBox(width: _iconGap),
            _menuButton(
              icon: switch (i) {
                0 => Icons.workspace_premium_outlined,
                1 => Icons.upload_outlined,
                2 => Icons.download_outlined,
                3 => Icons.settings_outlined,
                _ => Icons.help_outline_rounded,
              },
              label: switch (i) {
                0 => '成績証明証'.tr(languageCode),
                1 => 'エクスポート'.tr(languageCode),
                2 => 'インポート'.tr(languageCode),
                3 => '設定'.tr(languageCode),
                _ => 'ヘルプ'.tr(languageCode),
              },
              iconFg: iconFg,
              iconBg: iconBg,
              iconBorder: iconBorder,
              onTap: switch (i) {
                0 => onTranscript,
                1 => onExport,
                2 => onImport,
                3 => onSettings,
                _ => onHelp,
              },
            ),
          ],
        ],
      ),
    );

    final content = maxWidth == null || maxWidth! >= intrinsicWidth
        ? row
        : SizedBox(
            width: maxWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            ),
          );

    return Material(
      color: palette.cardFill,
      borderRadius: BorderRadius.circular(12),
      elevation: 6,
      child: content,
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required Color iconFg,
    required Color iconBg,
    required Color iconBorder,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconBorder, width: 1),
          ),
          child: Icon(icon, color: iconFg, size: _iconGlyphSize),
        ),
      ),
    );
  }
}
