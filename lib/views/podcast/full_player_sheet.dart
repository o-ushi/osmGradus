import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../audio/podcast_audio_handler.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// osmPodの `PlayerView`（フル再生画面）に相当。アートワーク、シークスライダー、
/// ±15秒、再生/一時停止、次のエピソードへのスキップを表示する。
/// 下/右スワイプで閉じる（戻るボタンなし）。
class FullPlayerSheet extends StatefulWidget {
  const FullPlayerSheet({super.key, required this.handler});

  final PodcastAudioHandler handler;

  static Future<void> show(BuildContext context, PodcastAudioHandler handler) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FullPlayerSheet(handler: handler),
    );
  }

  @override
  State<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends State<FullPlayerSheet> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: palette.cardFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: StreamBuilder<MediaItem?>(
              stream: widget.handler.mediaItem,
              builder: (context, mediaSnapshot) {
                final mediaItem = mediaSnapshot.data;
                if (mediaItem == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 2行に折り返すタイトル等でコンテンツが伸びると、固定高の
                      // シート内でSpacer運用のままだとボトムオーバーフローが
                      // 起きるため、収まらない時だけスクロールできるようにする。
                      // `minHeight`制約でコンテンツが短い時は中央寄せを保つ。
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: mediaItem.artUri != null
                                          ? Image.network(
                                              mediaItem.artUri.toString(),
                                              width: 200,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  _fallbackArt(palette),
                                            )
                                          : _fallbackArt(palette),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      mediaItem.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: palette.textOnCardPrimary,
                                      ),
                                    ),
                                    if (mediaItem.artist != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        mediaItem.artist!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: palette.textOnCardSecondary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    _buildSeekBar(palette, mediaItem),
                                    const SizedBox(height: 16),
                                    _buildTransportRow(palette),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeekBar(AppPalette palette, MediaItem mediaItem) {
    final duration = mediaItem.duration ?? Duration.zero;
    return StreamBuilder<Duration>(
      stream: widget.handler.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final maxMs = duration.inMilliseconds.toDouble().clamp(
          1,
          double.infinity,
        );
        final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
          0,
          maxMs,
        );
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: palette.accentColor,
                inactiveTrackColor: palette.cardBorder,
                thumbColor: palette.accentColor,
              ),
              child: Slider(
                value: value.toDouble(),
                max: maxMs.toDouble(),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  widget.handler.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(milliseconds: value.toInt())),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnCardSecondary,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnCardSecondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransportRow(AppPalette palette) {
    return StreamBuilder<PlaybackState>(
      stream: widget.handler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 32,
              onPressed: () => widget.handler.rewind(),
              icon: Icon(Icons.replay_10, color: palette.textOnCardPrimary),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: playing ? widget.handler.pause : widget.handler.play,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accentColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: palette.onAccent,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              iconSize: 32,
              onPressed: () => widget.handler.fastForward(),
              icon: Icon(Icons.forward_10, color: palette.textOnCardPrimary),
            ),
            const SizedBox(width: 24),
            IconButton(
              iconSize: 32,
              onPressed: () => widget.handler.skipToNext(),
              tooltip: '次のエピソードへ'.tr(appSettings.language),
              icon: Icon(Icons.skip_next, color: palette.textOnCardPrimary),
            ),
          ],
        );
      },
    );
  }

  Widget _fallbackArt(AppPalette palette) => Container(
    width: 200,
    height: 200,
    color: palette.cardBorder,
    child: Icon(Icons.podcasts, size: 64, color: palette.textOnCardSecondary),
  );

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
