import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// カテゴリ・タブ選択シート共通の1行（チェックマーク付き）。
class CategorySelectRow extends StatelessWidget {
  const CategorySelectRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: palette.accentColor),
          ],
        ),
      ),
    );
  }
}
