import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/question_prompt_tab_registry.dart';

/// 問題文編集フォームで「新しいタブ」を追加するときのダイアログ。
Future<String?> showQuestionPromptNewTagDialog(
  BuildContext context,
  String lang,
) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('新しいタブ'.tr(lang)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: QuestionPromptTabRegistry.maxTabNameLength,
        decoration: InputDecoration(hintText: 'タブ名を入力'.tr(lang)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('キャンセル'.tr(lang)),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text('追加'.tr(lang)),
        ),
      ],
    ),
  ).then((value) => value == null || value.isEmpty ? null : value);
}
