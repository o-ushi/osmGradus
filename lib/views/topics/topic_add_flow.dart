import 'package:flutter/material.dart';

import '../../models/topic_category.dart';
import '../../services/topic_json_transfer_actions.dart';
import 'topic_add_choice_sheet.dart';
import 'topic_import_screen.dart';
import 'topic_manual_add_screen.dart';

/// レイヤーⅡ・Ⅲ・Ⅳで共通の「＋」→ AI取込 / 手入力 / JSONインポート・
/// エクスポート フロー。
Future<void> showTopicAddChoiceFlow(
  BuildContext context, {
  required TopicCategory initialCategory,
}) async {
  final choice = await TopicAddChoiceSheet.show(context);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case TopicAddMethod.ai:
      await TopicImportScreen.push(context);
    case TopicAddMethod.manual:
      await TopicManualAddScreen.push(
        context,
        initialCategory: initialCategory,
      );
    case TopicAddMethod.jsonImport:
      await importTopicsJson(context);
    case TopicAddMethod.jsonExport:
      await exportTopicsJson(context);
  }
}
