import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../widgets/ipad_phone_scale.dart';

// 全データ・お題・問題文の JSON の書き出しと取り込み（3 つで同じ手順・同じ知らせ方）。

/// 書き出して共有シートを出す。[itemCount] が 0 なら [emptyKey] の文言を出す。
Future<void> shareJsonExport(
  BuildContext context, {
  required Future<int> Function() itemCount,
  required Future<File> Function() writeFile,
  required String emptyKey,
}) async {
  final lang = appSettings.language;
  try {
    final count = await itemCount();
    if (count == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyKey.tr(lang))));
      return;
    }

    final file = await writeFile();
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : Rect.fromPoints(
            box.localToGlobal(Offset.zero),
            box.localToGlobal(Offset(box.size.width, box.size.height)),
          );
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

/// JSON ファイルを選んで [importContent] で取り込み、追加・スキップの件数を知らせる。
Future<void> pickAndImportJson(
  BuildContext context, {
  required Future<({int added, int skipped})> Function(String content)
  importContent,
}) async {
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
    final result = await importContent(content);
    if (!context.mounted) return;

    final message = result.skipped > 0
        ? 'インポート_スキップ'.trFmt(lang, ['${result.added}', '${result.skipped}'])
        : result.added > 0
        ? 'インポート_追加'.trFmt(lang, ['${result.added}'])
        : 'インポート_すべてスキップ'.trFmt(lang, ['${result.skipped}']);

    await showDialog<void>(
      context: sidePaneContext(context),
      useRootNavigator: sidePaneUsesRootNavigator(context),
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
      context: sidePaneContext(context),
      useRootNavigator: sidePaneUsesRootNavigator(context),
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
