import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import 'choice_sheet.dart';

/// 起動画面「•••」のエクスポート／インポート対象範囲。
enum BackupScope { questionPromptsOnly, everything }

/// 起動画面「•••」のエクスポート／インポート共通の入口。「問題のみ」／
/// 「全て」のどちらを対象にするかを選ぶ（[TopicAddChoiceSheet]と同じ
/// トーンの選択シート）。
class BackupScopeSheet extends StatelessWidget {
  const BackupScopeSheet({super.key, required this.title});

  final String title;

  static Future<BackupScope?> show(
    BuildContext context, {
    required String title,
  }) {
    return showChoiceSheet<BackupScope>(
      context,
      (_) => BackupScopeSheet(title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return ChoiceSheet<BackupScope>(
      title: title,
      choices: [
        ChoiceItem(
          icon: Icons.assignment_rounded,
          label: '問題のみ'.tr(lang),
          subtitle: 'バックアップ範囲_説明_問題のみ'.tr(lang),
          value: BackupScope.questionPromptsOnly,
        ),
        ChoiceItem(
          icon: Icons.all_inclusive_rounded,
          label: '全て'.tr(lang),
          subtitle: 'バックアップ範囲_説明_全て'.tr(lang),
          value: BackupScope.everything,
        ),
      ],
    );
  }
}
