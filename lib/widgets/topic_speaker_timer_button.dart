import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// レイヤーⅢのお題ボタンの3状態。
enum TopicSpeakerTimerPhase {
  /// お題未読み上げ。サイコロのアイコンを表示し、タップでお題を引いて読み上げ開始。
  idle,

  /// お題を読み上げ中。スピーカー（一時停止中はポーズ）アイコンを表示し、
  /// タップで一時停止/再開する。
  speaking,

  /// カウントダウン中。osmGenkiの`_MicButton`と同じ見た目（大きな白文字の数字）で
  /// 残り秒数を表示し、タップでタイマーの一時停止/再開する。
  counting,
}

/// サイコロ→スピーカー→カウントダウンと1つのボタンの中で状態が移り変わる、
/// レイヤーⅢ専用のお題ボタン。レイヤーⅡ→Ⅲと移動したときに見た目が変わって
/// 見えないよう、直径・影（なし）ともosmGenkiの`_MicButton`ではなく
/// レイヤーⅡのサイコロボタンにそのまま合わせる。
class TopicSpeakerTimerButton extends StatelessWidget {
  const TopicSpeakerTimerButton({
    super.key,
    required this.phase,
    this.remainingSeconds,
    this.isPaused = false,
    required this.onTap,
    this.size = 140,
  });

  /// ボタンの高さ（幅はこの2倍）。内側のアイコン/数字は余白ゼロで
  /// この高さいっぱいまで表示する。
  final double size;

  final TopicSpeakerTimerPhase phase;

  /// phaseがcountingのときのみ使う残り秒数。
  final int? remainingSeconds;

  /// phaseがspeakingのとき、読み上げが一時停止中ならtrue。
  /// trueのときスピーカーの代わりにポーズアイコンを出す。
  final bool isPaused;

  final VoidCallback onTap;

  static const double _baseCountingFontSize = 88;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = appSettings.language;

    final onAccent = palette.onAccent;
    // 余白ゼロ：アイコン/数字をボタンの高さいっぱいまで大きくする。
    final iconSize = size;

    final Widget content;
    switch (phase) {
      case TopicSpeakerTimerPhase.idle:
        content = Icon(Icons.casino, size: iconSize, color: onAccent);
      case TopicSpeakerTimerPhase.speaking:
        final speakingIcon = Icon(
          isPaused ? Icons.pause : Icons.volume_up,
          size: iconSize,
          color: onAccent,
        );
        content = Tooltip(
          message: isPaused ? '読み上げ一時停止'.tr(lang) : '読み上げ'.tr(lang),
          child: speakingIcon,
        );
      case TopicSpeakerTimerPhase.counting:
        // 秒数は1桁・2桁で幅が変わる。ボタン全体（高さsize×幅size*2）を
        // BoxFit.containで使い切り、桁数によらず可能な限り大きく表示する
        // （余白ゼロ）。
        content = SizedBox(
          width: size * 2,
          height: size,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              '${remainingSeconds ?? 0}',
              style: TextStyle(
                color: onAccent,
                fontSize: _baseCountingFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // 横長の長方形にする：高さはsize基準のまま、幅だけ2倍にする。
        width: size * 2,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: Colors.transparent,
        ),
        child: content,
      ),
    );
  }
}
