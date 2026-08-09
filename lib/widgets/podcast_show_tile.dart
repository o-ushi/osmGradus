import 'package:flutter/material.dart';

import '../models/podcast_show.dart';
import '../theme/app_colors.dart';

/// 番組追加画面（おすすめ／検索結果）で共通して使う行。
/// 未登録なら＋、登録済みならゴミ箱アイコンを表示し、タップで登録/削除する。
class PodcastShowTile extends StatelessWidget {
  const PodcastShowTile({
    super.key,
    required this.show,
    required this.isRegistered,
    required this.onTap,
    this.subtitle,
  });

  final PodcastShow show;
  final bool isRegistered;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: show.artworkUrl != null
                  ? Image.network(
                      show.artworkUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackArt(palette),
                    )
                  : _fallbackArt(palette),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
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
            Icon(
              isRegistered ? Icons.delete_outline : Icons.add_circle_outline,
              color: isRegistered ? Colors.red : palette.textOnCardSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackArt(AppPalette palette) => Container(
    width: 48,
    height: 48,
    color: palette.cardBorder,
    child: Icon(Icons.podcasts, color: palette.textOnCardSecondary),
  );
}
