import 'package:flutter/material.dart';

import '../../models/podcast_episode.dart';
import '../../theme/app_colors.dart';

/// osmPodの `EpisodeRowView` の見た目を移植。左にタイトル・日付/再生時間、
/// 右にお気に入り（★）と状態ドット（🟢新着 / 🟡再生中 / 🔵再生済み）を並べる。
///
/// osmPodと同じく、行そのものは枠を持たない。番組の全エピソードが1枚の
/// カード（[Layer1Screen] 側で用意する外枠）の中に並び、行同士は罫線のみで
/// 区切られる。
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    super.key,
    required this.episode,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final PodcastEpisode episode;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  static const _newColor = Color(0xFF34C759);
  static const _inProgressColor = Color(0xFFFFCC00);
  static const _playedColor = Color(0xFF007AFF);

  Color? get _statusColor {
    if (episode.isNew) return _newColor;
    if (episode.isPlayed) return _playedColor;
    if (episode.isInProgress) return _inProgressColor;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? palette.accentColor
                          : palette.textOnCardPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                  if (episode.progress > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: episode.progress,
                        minHeight: 3,
                        backgroundColor: palette.cardBorder,
                        color: palette.accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Icon(
                    episode.isFavorite ? Icons.star : Icons.star_border,
                    size: 22,
                    color: episode.isFavorite
                        ? const Color(0xFFFFCC00)
                        : palette.textOnCardSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (_statusColor != null)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// osmPodと同じく、日付は常に表示し、再生位置がある場合のみ
  /// 「位置 / 総尺」を続けて表示する（未再生では時間を出さない）。
  String _subtitle() {
    final parts = <String>[];
    final date = episode.publishedAt;
    if (date != null) {
      parts.add(
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
      );
    }
    if (episode.playbackPosition > Duration.zero) {
      final position = _formatDuration(episode.playbackPosition);
      final total = _formatDuration(episode.totalDuration);
      parts.add('$position / $total');
    }
    return parts.join('  ');
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
