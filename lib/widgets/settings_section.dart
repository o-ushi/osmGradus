import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/surface_theme.dart';

/// 設定画面で共通する「セクション見出し＋カード＋区切り線」の部品群。
/// osmWashabeの`SettingsView`にあった私有ウィジェットを再利用できるよう
/// 1箇所に切り出したもの。

/// 赤文字1行の破壊的アクション（初期化・リセット等）。[enabled]がfalseの間は
/// 淡色化してタップも無効になる。
class SettingsDestructiveActionRow extends StatelessWidget {
  const SettingsDestructiveActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.red : Colors.red.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(label, style: TextStyle(fontSize: 17, color: color)),
      ),
    );
  }
}

/// セクション見出し（カードの上に乗る小さいグレー文字）。[icon]を渡すと
/// 見出しの左にアイコンが付く（osmWashabeの読み上げ/タイマー設定と同じ）。
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final style = TextStyle(
      color: palette.textOnSubpageSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: icon == null
          ? Text(title, style: style)
          : Row(
              children: [
                Icon(icon, size: 15, color: palette.textOnSubpageSecondary),
                const SizedBox(width: 4),
                Text(title, style: style),
              ],
            ),
    );
  }
}

/// セクション見出しの下に付く補足説明文。
class SettingsNoteText extends StatelessWidget {
  const SettingsNoteText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(
        text,
        style: TextStyle(color: palette.textOnSubpageSecondary, fontSize: 13),
      ),
    );
  }
}

/// [AppPalette.cardFill]で塗られた角丸カード。中に置く行の文字色は
/// [SurfaceTheme.card]で自動的にコントラスト調整される。
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: SurfaceTheme.card(context),
        child: Material(
          color: palette.cardFill,
          child: Column(children: children),
        ),
      ),
    );
  }
}

/// カード内の行同士を区切る薄い線。
class SettingsItemDivider extends StatelessWidget {
  const SettingsItemDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: palette.cardBorder,
    );
  }
}

/// ラベル＋chevronだけの1行（値を持たない、別画面への導線専用）。
/// 「音声認識ログ」など、値のプレビューを持たないナビゲーションに使う。
class SettingsNavigationRow extends StatelessWidget {
  const SettingsNavigationRow({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: palette.textOnCardSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// ラベル＋値（＋任意でchevron/unfold_moreアイコン）の1行。値だけを表示する
/// 読み取り専用行にも、ピッカーを開くタップ可能な行にも使う。
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 17, color: palette.textOnCardPrimary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textOnCardSecondary,
                fontSize: 17,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.unfold_more,
              size: 20,
              color: palette.textOnCardSecondary,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

/// チェックマーク付きの選択行（言語など、リストから1つ選ぶ設定で使う）。
/// [leading]にアイコンを差し込み、[subtitle]は任意。
class SettingsSelectableRow extends StatelessWidget {
  const SettingsSelectableRow({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: palette.textOnCardSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, color: palette.accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}

/// ON/OFFスイッチ付きの1行。ラベルタップでもトグルする。
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final labelColor = enabled
        ? palette.textOnCardPrimary
        : palette.textOnCardPrimary.withValues(alpha: 0.4);
    final subtitleColor = enabled
        ? palette.textOnCardSecondary
        : palette.textOnCardSecondary.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      color: labelColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: palette.onAccent,
              activeTrackColor: palette.accentColor,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
