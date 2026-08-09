import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import 'topic_json_transfer.dart';

/// お題を追加シートの「エクスポート」。取り込み済みお題だけをJSONファイルに
/// 書き出して共有する（[TopicImportScreen]のAI取り込みとは別の、
/// ファイル入出力用の導線）。
Future<void> exportTopicsJson(BuildContext context) async {
  final lang = appSettings.language;
  try {
    final count = await TopicJsonTransfer.itemCount();
    if (count == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エクスポートするお題がありません'.tr(lang))));
      return;
    }

    final file = await TopicJsonTransfer.writeExportFile();
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/json',
            name: file.uri.pathSegments.last,
          ),
        ],
        subject: 'エクスポート'.tr(lang),
        text: 'データをエクスポートしました'.tr(lang),
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('エクスポートに失敗しました'.tr(lang))));
  }
}

/// お題を追加シートの「インポート」。JSONファイルを選び、取り込み済み
/// お題へマージする（重複は追加しない）。壊れたJSONやスキーマ違反は
/// 例外を投げずにエラーダイアログで案内する。
Future<void> importTopicsJson(BuildContext context) async {
  final lang = appSettings.language;
  const jsonType = XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );
  final file = await openFile(acceptedTypeGroups: [jsonType]);
  if (file == null || !context.mounted) return;

  try {
    final content = await file.readAsString();
    final result = await TopicJsonTransfer.importFromContent(content);
    if (!context.mounted) return;

    final message = result.skipped > 0
        ? 'インポート_スキップ'.trFmt(lang, ['${result.added}', '${result.skipped}'])
        : result.added > 0
        ? 'インポート_追加'.trFmt(lang, ['${result.added}'])
        : 'インポート_すべてスキップ'.trFmt(lang, ['${result.skipped}']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('インポート完了'.tr(lang)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK'.tr(lang)),
          ),
        ],
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('インポートエラー'.tr(lang)),
        content: Text('インポートに失敗しました'.tr(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK'.tr(lang)),
          ),
        ],
      ),
    );
  }
}
