import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../audio/podcast_audio_handler.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import 'full_player_sheet.dart';

/// osmPodの `MiniPlayerView` に相当。再生中のエピソードがある間、常時
/// 画面下部に表示される「再生中のデッキ」。タップでフルプレイヤーを開く。
/// osmPodと同じく±15秒シーク・再生/一時停止を並べ、それに加えて次の
/// エピソードへのスキップボタンも置く（osmPodのミニプレイヤーには無いが、
/// フルプレイヤーを開かず番組を進められた方が使い勝手が良いための追加）。
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.handler});

  final PodcastAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, playbackSnapshot) {
            final playing = playbackSnapshot.data?.playing ?? false;
            return GestureDetector(
              onTap: () => FullPlayerSheet.show(context, handler),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.cardFill,
                  border: Border(top: BorderSide(color: palette.cardBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: mediaItem.artUri != null
                            ? Image.network(
                                mediaItem.artUri.toString(),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _fallbackArt(palette),
                              )
                            : _fallbackArt(palette),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mediaItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textOnCardPrimary,
                              ),
                            ),
                            if (mediaItem.artist != null)
                              Text(
                                mediaItem.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textOnCardSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => handler.rewind(),
                        icon: Icon(
                          Icons.replay_10,
                          color: palette.textOnCardPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: playing ? handler.pause : handler.play,
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: palette.accentColor,
                          size: 34,
                        ),
                      ),
                      IconButton(
                        onPressed: () => handler.fastForward(),
                        icon: Icon(
                          Icons.forward_10,
                          color: palette.textOnCardPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => handler.skipToNext(),
                        tooltip: '次のエピソードへ'.tr(appSettings.language),
                        icon: Icon(
                          Icons.skip_next,
                          color: palette.textOnCardPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fallbackArt(AppPalette palette) => Container(
    width: 40,
    height: 40,
    color: palette.cardBorder,
    child: Icon(Icons.podcasts, size: 20, color: palette.textOnCardSecondary),
  );
}
