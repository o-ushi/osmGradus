import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// 直近の録音ファイルを再生⇄一時停止する共通処理。
mixin LastRecordingPlaybackMixin<T extends StatefulWidget> on State<T> {
  final AudioPlayer playbackPlayer = AudioPlayer();
  bool isPlayingLastRecording = false;
  StreamSubscription<PlayerState>? _playbackStateSub;

  void initLastRecordingPlayback() {
    _playbackStateSub = playbackPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (isPlayingLastRecording != playing) {
        setState(() => isPlayingLastRecording = playing);
      }
    });
  }

  void disposeLastRecordingPlayback() {
    unawaited(_playbackStateSub?.cancel());
    playbackPlayer.dispose();
  }

  Future<void> toggleLastRecordingPlayback(String? path) async {
    if (path == null) return;
    if (isPlayingLastRecording) {
      setState(() => isPlayingLastRecording = false);
      await playbackPlayer.pause();
      return;
    }
    setState(() => isPlayingLastRecording = true);
    try {
      await playbackPlayer.setFilePath(path);
      await playbackPlayer.play();
    } catch (_) {
      if (mounted) setState(() => isPlayingLastRecording = false);
    }
  }

  Future<void> stopLastRecordingPlayback() async {
    await playbackPlayer.stop();
    if (mounted) setState(() => isPlayingLastRecording = false);
  }
}
