import 'package:flutter/material.dart';

import '../main.dart';
import 'gradus_backup.dart';
import 'json_file_actions.dart';

Future<void> exportGradusData(BuildContext context) => shareJsonExport(
  context,
  itemCount: GradusBackup.itemCount,
  writeFile: GradusBackup.writeExportFile,
  emptyKey: 'エクスポートするデータがありません',
);

Future<void> importGradusData(BuildContext context) => pickAndImportJson(
  context,
  importContent: (content) async {
    final result = await GradusBackup.importFromContent(content);
    // インポートしたpreferences（言語・読み上げ設定・タイマー音・
    // 補正係数など）を、内部にキャッシュを持つ各サービスへ反映する
    // （SharedPreferences自体は書き換わっているが、これらのサービスは
    // load()を呼ぶまで古い値をメモリに保持し続けるため）。
    await ttsSettings.load();
    await jsstCalibrationPreferences.load();
    appSettings.refresh();
    return (added: result.added, skipped: result.skipped);
  },
);
