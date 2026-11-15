import 'package:flutter/material.dart';

import 'json_file_actions.dart';
import 'topic_json_transfer.dart';

/// お題を追加シートの「エクスポート」。取り込み済みお題だけをJSONファイルに
/// 書き出して共有する（[TopicImportScreen]のAI取り込みとは別の、
/// ファイル入出力用の導線）。
Future<void> exportTopicsJson(BuildContext context) => shareJsonExport(
  context,
  itemCount: TopicJsonTransfer.itemCount,
  writeFile: TopicJsonTransfer.writeExportFile,
  emptyKey: 'エクスポートするお題がありません',
);

/// お題を追加シートの「インポート」。JSONファイルを選び、取り込み済み
/// お題へマージする（重複は追加しない）。壊れたJSONやスキーマ違反は
/// 例外を投げずにエラーダイアログで案内する。
Future<void> importTopicsJson(BuildContext context) => pickAndImportJson(
  context,
  importContent: (content) async {
    final result = await TopicJsonTransfer.importFromContent(content);
    return (added: result.added, skipped: result.skipped);
  },
);
