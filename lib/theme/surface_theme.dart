import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 画面の「面」（サブページ背景・カード面など）ごとに、
/// 背景色に溶けない [ThemeData] を組み立てる。
abstract final class SurfaceTheme {
  /// 設定・ヘルプ・履歴一覧など [AppPalette.subpageBackground] 上の UI 用。
  static ThemeData subpage(BuildContext context) {
    final palette = AppColors.current;
    final base = Theme.of(context);
    final fg = palette.textOnSubpagePrimary;
    final muted = palette.textOnSubpageSecondary;

    return base.copyWith(
      scaffoldBackgroundColor: palette.subpageBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.subpageBackground,
        foregroundColor: fg,
        iconTheme: IconThemeData(color: fg),
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      listTileTheme: ListTileThemeData(textColor: fg, iconColor: muted),
      dividerColor: muted.withValues(alpha: 0.28),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accentColor,
      ),
    );
  }

  /// [AppPalette.cardFill] 上のリスト・フォーム・セクションカード用。
  static ThemeData card(BuildContext context) {
    final palette = AppColors.current;
    final base = Theme.of(context);
    final fg = palette.textOnCardPrimary;
    final muted = palette.textOnCardSecondary;

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      listTileTheme: ListTileThemeData(textColor: fg, iconColor: muted),
      dividerColor: palette.cardBorder.withValues(alpha: 0.45),
      iconTheme: IconThemeData(color: muted),
    );
  }
}
