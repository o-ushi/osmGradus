import 'package:flutter/material.dart';

import '../models/question_prompt.dart';
import '../theme/app_colors.dart';
import 'layer_numeral_badge.dart';

/// 起動画面から開く横断問題文一覧の1行。
///
/// `総評 | Ⅰ | Ⅱ | Ⅲ | Ⅳ | Ⅴ | 本文` の列構成。Ⅰ〜Ⅴは起動画面と同じ
/// [LayerNumeralIcon]（実施済=塗り、未実施=枠線）。総評が ⭕️ のときだけ
/// そのセルをタップでき、[onSummaryTap]で総評画面へ進む。Ⅰ〜Ⅴは
/// [onLayerTap]が渡されていればタップで該当レイヤー詳細へ進む。
class QuestionPromptOverviewRow extends StatelessWidget {
  const QuestionPromptOverviewRow({
    super.key,
    required this.prompt,
    required this.onSummaryTap,
    this.onLayerTap,
  });

  final QuestionPrompt prompt;
  final VoidCallback onSummaryTap;

  /// 0=Ⅰ〜4=Ⅴ。nullならレイヤーアイコンは非インタラクティブ。
  final ValueChanged<int>? onLayerTap;

  /// 各レイヤー列の幅（ヘッダーと揃える）。
  static const double layerColumnWidth = 30;

  /// 総評列に出す実施済みマーク（タップで総評画面）。
  static const summaryMarker = '⭕️';

  static bool _layerDone(QuestionPrompt prompt, int layerIndex) =>
      switch (layerIndex) {
        0 => prompt.isLayer1Done,
        1 => prompt.isLayer2Done,
        2 => prompt.isLayer3Done,
        3 => prompt.isLayer4Done,
        _ => prompt.isLayer5Done,
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final showSummary = prompt.showsOverviewSummaryMarker;
    final onLayerTap = this.onLayerTap;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: showSummary
                ? InkWell(
                    onTap: onSummaryTap,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        summaryMarker,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                : Text(
                    'ー',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textOnSceneSecondary,
                    ),
                  ),
          ),
          for (var i = 0; i < 5; i++)
            SizedBox(
              width: layerColumnWidth,
              child: Center(
                child: onLayerTap == null
                    ? LayerNumeralIcon(
                        layerIndex: i,
                        size: 22,
                        filled: _layerDone(prompt, i),
                      )
                    : InkWell(
                        onTap: () => onLayerTap(i),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: LayerNumeralIcon(
                            layerIndex: i,
                            size: 22,
                            filled: _layerDone(prompt, i),
                          ),
                        ),
                      ),
              ),
            ),
          Expanded(
            child: Text(
              prompt.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: palette.textOnScenePrimary),
            ),
          ),
        ],
      ),
    );
  }
}
