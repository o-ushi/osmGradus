import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_strings.dart';
import '../main.dart';
import 'gradus_backup.dart';

Future<void> exportGradusData(BuildContext context) async {
  final lang = appSettings.language;
  try {
    final count = await GradusBackup.itemCount();
    if (count == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エクスポートするデータがありません'.tr(lang))));
      return;
    }

    final file = await GradusBackup.writeExportFile();
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

Future<void> importGradusData(BuildContext context) async {
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
    final result = await GradusBackup.importFromContent(content);

    // インポートしたpreferences（言語・読み上げ設定・タイマー音・
    // 補正係数など）を、内部にキャッシュを持つ各サービスへ反映する
    // （SharedPreferences自体は書き換わっているが、これらのサービスは
    // load()を呼ぶまで古い値をメモリに保持し続けるため）。
    await ttsSettings.load();
    await jsstCalibrationPreferences.load();
    appSettings.refresh();
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
