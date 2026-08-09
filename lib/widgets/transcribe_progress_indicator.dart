import 'package:flutter/material.dart';

import '../services/recording_stt_service.dart';
import '../theme/app_colors.dart';

/// 音声→テキスト化（文字起こし）の進捗表示。osmWashabeの`ScoringResultView`の
/// 採点中プログレスバーの移植。Android は Vosk フォールバック時に細かい進捗を、
/// iOS は Speech フレームワークの部分認識位置から進捗を近似する。
/// レイヤーⅣ（採点）・レイヤーⅤ（発音チェック）の両方で使う共通ウィジェット。
///
/// [compact]がtrueのときは、[GenkiTransportRow]（高さ56）の上にそのまま
/// 重ねて表示できる横1行のレイアウトになる。文字起こし中だけ縦方向に
/// 別枠を足すと、その分だけ上のExpanded領域が縮んでボタン列全体が
/// 上にずれて見えてしまうため、レイアウトの高さを変えずに同じ場所へ
/// 重ねて表示する。
class TranscribeProgressIndicator extends StatelessWidget {
  const TranscribeProgressIndicator({
    super.key,
    required this.progress,
    required this.phase,
    this.compact = false,
    this.active = false,
  });

  final double progress;
  final String phase;

  /// [GenkiTransportRow]の上に重ねる横1行レイアウト。
  final bool compact;

  /// 文字起こし処理中かどうか。osmWashabeの`isOfflineTranscribing`と同様、
  /// 進捗 0% の段階からプログレスバーとフェーズ文言を出す。
  final bool active;

  bool get _showDetailedProgress => active || progress > 0;

  String get _phaseLabel =>
      phase.isNotEmpty ? phase : RecordingSttService.phaseAnalyzing;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    if (compact) {
      if (_showDetailedProgress) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress.clamp(0.02, 1.0) : null,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              progress > 0 ? '${(progress * 100).round()}%' : '…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textOnScenePrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      }
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_showDetailedProgress) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress.clamp(0.02, 1.0) : null,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          if (progress > 0) ...[
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: palette.textOnScenePrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _phaseLabel,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.textOnSceneSecondary),
          ),
        ],
      );
    }
    return Column(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 8),
        Text(
          _phaseLabel,
          style: TextStyle(fontSize: 12, color: palette.textOnSceneSecondary),
        ),
      ],
    );
  }
}
