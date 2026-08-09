import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// 履歴一覧の左スワイプ削除で使う確認ダイアログ。
Future<bool> confirmHistoryDelete(
  BuildContext context, {
  required String languageCode,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('削除しますか？'.tr(languageCode)),
      content: Text('一度削除すると元に戻せません。'.tr(languageCode)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('キャンセル'.tr(languageCode)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('削除'.tr(languageCode)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
