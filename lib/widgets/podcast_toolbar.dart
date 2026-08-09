import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import 'ghost_pill.dart';

/// スキップ・ランダム・並べ替えの3ボタンを横幅いっぱいに等分し、番組登録は
/// [DiceActionRow]の「＋」と同じく固定サイズのピルとして右端に置く。
/// レイヤーⅡ〜Ⅴの上端ボタン列と同じ[GhostPill]を使うことで、
/// サイズ・余白を完全に一致させている。
/// 登録番組が0件のときは[showPlaybackControls]をfalseにすると、スキップ・
/// ランダム・並べ替えの3つを他レイヤーの未使用ボタンと同じくゴースト化できる
/// （枠だけ確保し、「＋」は右端の位置のまま常に操作できる）。
class PodcastToolbar extends StatelessWidget {
  const PodcastToolbar({
    super.key,
    required this.onSkipNext,
    required this.isRandomEnabled,
    required this.onToggleRandom,
    required this.onOpenSort,
    required this.onAddShow,
    this.onAddShowLongPress,
    this.showPlaybackControls = true,
  });

  final VoidCallback onSkipNext;
  final bool isRandomEnabled;
  final VoidCallback onToggleRandom;
  final VoidCallback onOpenSort;
  final VoidCallback onAddShow;

  /// 非nullの場合、「＋」の長押しで呼ぶ（レイヤーⅠの使い方シートを開く導線）。
  final VoidCallback? onAddShowLongPress;
  final bool showPlaybackControls;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Row(
      children: [
        Expanded(
          child: GhostPill(
            icon: Icons.skip_next,
            tooltip: '次のエピソードへ'.tr(lang),
            visible: showPlaybackControls,
            onTap: onSkipNext,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GhostPill(
            icon: Icons.shuffle,
            tooltip: 'ランダム再生'.tr(lang),
            visible: showPlaybackControls,
            active: isRandomEnabled,
            activeFill: palette.accentColor,
            activeForeground: palette.onAccent,
            onTap: onToggleRandom,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GhostPill(
            icon: Icons.swap_vert,
            tooltip: '並べ替え'.tr(lang),
            visible: showPlaybackControls,
            onTap: onOpenSort,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: GhostPill(
            icon: Icons.add_rounded,
            tooltip: '番組を追加'.tr(lang),
            onTap: onAddShow,
            onLongPress: onAddShowLongPress,
            showBorder: false,
            horizontalPadding: 0,
          ),
        ),
      ],
    );
  }
}
