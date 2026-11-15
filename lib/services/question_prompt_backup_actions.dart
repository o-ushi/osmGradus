import 'package:flutter/material.dart';

import 'json_file_actions.dart';
import 'question_prompt_json_transfer.dart';

/// 起動画面「•••」のエクスポートで「問題のみ」を選んだときの処理
/// （[QuestionPromptJsonTransfer]で問題文だけをJSONファイルに書き出して共有する）。
Future<void> exportQuestionPromptsData(BuildContext context) => shareJsonExport(
  context,
  itemCount: QuestionPromptJsonTransfer.itemCount,
  writeFile: QuestionPromptJsonTransfer.writeExportFile,
  emptyKey: 'エクスポートする問題文がありません',
);

/// 起動画面「•••」のインポートで「問題のみ」を選んだときの処理。
Future<void> importQuestionPromptsData(BuildContext context) => pickAndImportJson(
  context,
  importContent: (content) async {
    final result = await QuestionPromptJsonTransfer.importFromContent(content);
    return (added: result.added, skipped: result.skipped);
  },
);
