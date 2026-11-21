import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ipad_phone_scale.dart';

/// [ChoiceSheet] の 1 行。
class ChoiceItem<T> {
  const ChoiceItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  /// 選んだときにシートが返す値。
  final T value;
}

/// 角の丸い、選ぶためのシートを出す（お題の追加・長文の始め方・バックアップの範囲）。
Future<T?> showChoiceSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: sidePaneContext(context),
      backgroundColor: AppColors.current.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: builder,
    );

/// つまみ・見出し・選択肢の行（アイコン・名前・説明・＞）。選んだ行の値で閉じる。
class ChoiceSheet<T> extends StatelessWidget {
  const ChoiceSheet({super.key, required this.title, required this.choices});

  final String title;
  final List<ChoiceItem<T>> choices;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 4),
              for (final choice in choices)
                _ChoiceRow(
                  icon: choice.icon,
                  label: choice.label,
                  subtitle: choice.subtitle,
                  onTap: () => Navigator.of(context).pop(choice.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: palette.textOnCardPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textOnCardSecondary),
          ],
        ),
      ),
    );
  }
}
