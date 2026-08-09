import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Chrome AIの回答原文（解析済みの`rawResponse`、または解析に失敗した場合の
/// `unparsedResponse`）を表示する共通カード。
/// [PronunciationCheckDetailScreen]・[VocabularyCheckDetailScreen]で共有する。
class HistoryRawResponseCard extends StatelessWidget {
  const HistoryRawResponseCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: SelectableText(
        text,
        style: TextStyle(fontSize: 13, color: palette.textOnCardPrimary),
      ),
    );
  }
}
