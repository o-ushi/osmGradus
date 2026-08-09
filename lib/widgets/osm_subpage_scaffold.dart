import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/surface_theme.dart';
import 'swipe_to_close_wrapper.dart';

/// 設定・ヘルプ・履歴など、サブページ背景上に表示する画面の共通骨格。
/// AppBar タイトルとリストの文字色を [AppPalette.subpageBackground] に
/// 合わせて自動コントラストさせる。
class OsmSubpageScaffold extends StatelessWidget {
  const OsmSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: Theme(
        data: SurfaceTheme.subpage(context),
        child: Scaffold(
          backgroundColor: palette.subpageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: title,
            actions: actions,
          ),
          body: body,
        ),
      ),
    );
  }
}
