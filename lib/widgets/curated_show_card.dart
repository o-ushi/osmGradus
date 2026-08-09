import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 番組追加画面のおすすめセクションで使う説明カード。
/// 第三者の番組名・アートワークは表示せず、学習者向けの説明のみを載せる。
class CuratedShowCard extends StatelessWidget {
  const CuratedShowCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.subpageBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.hearing_outlined,
                color: palette.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accentColor,
                ),
              )
            else
              Icon(
                Icons.search,
                color: palette.textOnCardSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
