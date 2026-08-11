import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'appearance_resolver.dart';

/// [AppColors.current] からアプリ全体の [ThemeData] を組み立てる。
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final palette = AppColors.current;
    // Material の既定色はカード面基準。シーン／サブページは各画面で
    // [SurfaceTheme] または [AppPalette] の明示色で上書きする。
    final cardIsLight = AppearanceResolver.isLightSurface(palette.cardFill);

    return ThemeData(
      useMaterial3: true,
      brightness: cardIsLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: palette.scene,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accentColor,
        brightness: cardIsLight ? Brightness.light : Brightness.dark,
        primary: palette.accentColor,
        onPrimary: palette.onAccent,
        secondary: palette.cardAccent,
        onSecondary: AppearanceResolver.onFill(palette.cardAccent),
        surface: palette.cardFill,
        onSurface: palette.textOnCardPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.subpageBackground,
        foregroundColor: palette.textOnSubpagePrimary,
        iconTheme: IconThemeData(color: palette.textOnSubpagePrimary),
        titleTextStyle: TextStyle(
          color: palette.textOnSubpagePrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: palette.cardBorder,
      textTheme: Typography.blackMountainView.apply(
        bodyColor: palette.textOnCardPrimary,
        displayColor: palette.textOnCardPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // 全画面が独自の端スワイプ閉じる操作（[SwipeToCloseWrapper]、生の
      // [Listener]でジェスチャーアリーナに参加しない実装）を持つため、
      // Flutter既定のプラットフォーム別インタラクティブ戻るジェスチャー
      // （iOS/macOSの[CupertinoPageTransitionsBuilder]の端スワイプ、
      // Androidの[PredictiveBackPageTransitionsBuilder]）は無効化する。
      // 既定のままだと、[SwipeToCloseWrapper]と同じ左端スワイプに両方の
      // ジェスチャー系統が同時に反応し、SnackBar表示中（SnackBarはFlutter
      // 内部で`transitionOnUserGestures: true`のHeroを持つ）に競合すると
      // 「multiple heroes share the same tag」からアサーション連鎖に陥り、
      // 以後タップ操作を含め一切反応しなくなる（実機で確認済みの不具合）。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
