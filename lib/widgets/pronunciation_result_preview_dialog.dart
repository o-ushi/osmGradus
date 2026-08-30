import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/pronunciation_evaluation.dart';
import 'pronunciation_evaluation_result_view.dart';

/// レイヤーⅤ（短・長文音読）でChrome AI評価を保存した直後に、その場で
/// ★評価の概要を見せるプレビューダイアログ。過去分の詳細は結果ボタン
/// （タップ＝最新詳細、長押し＝一覧）から開く。
Future<void> showPronunciationResultPreviewDialog(
  BuildContext context, {
  required PronunciationEvaluation evaluation,
  required String languageCode,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('評価結果プレビュー'.tr(languageCode)),
      content: SingleChildScrollView(
        child: PronunciationEvaluationResultView(
          evaluation: evaluation,
          languageCode: languageCode,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('完了'.tr(languageCode)),
        ),
      ],
    ),
  );
}
