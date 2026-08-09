import 'package:flutter/material.dart';

import '../data/jsst_reference_samples.dart';
import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/scoring_models.dart';
import '../services/jsst_scoring_service.dart';
import '../theme/app_colors.dart';
import '../utils/history_timestamp.dart';

/// 採点結果一覧（[ScoringHistoryScreen]）の1件分の要約カード。
/// [PronunciationHistoryScreen]・[VocabularyCheckHistoryScreen]の一覧カードと
/// 同じく、日時・見出しの指標・短い抜粋だけのコンパクト表示にとどめ、
/// 待遇表現／テキストタイプ／時間の使い方の内訳はタップ後の
/// [ScoringResultScreen]（判定まとめカードに同じ内容がある）に譲る。
/// 音声は保存しないため再生ボタンは持たない（削除は一覧側のスワイプで行う）。
class ScoringResultCard extends StatelessWidget {
  const ScoringResultCard({
    super.key,
    required this.result,
    this.createdAt,
    this.prepStars,
    this.hitStars,
  });

  final ScoringResult result;
  final DateTime? createdAt;

  /// Chrome AIによるPREP・的中度（Step 8）。未送信・旧データではnull。
  final int? prepStars;
  final int? hitStars;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final level = JsstScoringService.combinedReferenceLevel(result);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt != null)
            Text(
              formatHistoryTimestamp(createdAt!, languageCode: lang),
              style: TextStyle(
                fontSize: 12,
                color: palette.textOnCardSecondary,
              ),
            ),
          const SizedBox(height: 6),
          if (level != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.cardAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${'参考レベル感'.tr(lang)} ${JsstReferenceSamples.levelLabel(level)}',
                  style: TextStyle(
                    color: palette.onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (prepStars != null && hitStars != null) ...[
            const SizedBox(height: 4),
            _PrepHitStarRow(
              label: 'PREP評価'.tr(lang),
              stars: _starDisplay(prepStars!),
              color: palette.textOnCardSecondary,
            ),
            _PrepHitStarRow(
              label: '的中度'.tr(lang),
              stars: _starDisplay(hitStars!),
              color: palette.textOnCardSecondary,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            result.fullTranscript.isEmpty
                ? '発話を認識できませんでした'.tr(lang)
                : result.fullTranscript,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }

  String _starDisplay(int stars) => '★' * stars + '☆' * (5 - stars);
}

/// PREP評価・的中度の1行分（ラベル＋★）。★はカード右端に揃えて表示し、
/// ラベルの長さが違っても2行の★の横位置が揃うようにする。
class _PrepHitStarRow extends StatelessWidget {
  const _PrepHitStarRow({
    required this.label,
    required this.stars,
    required this.color,
  });

  final String label;
  final String stars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(stars, style: TextStyle(fontSize: 12, color: color)),
          ),
        ),
      ],
    );
  }
}
