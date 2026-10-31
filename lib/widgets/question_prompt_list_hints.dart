import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import 'button_action_hint.dart';

/// 問題文一覧系画面のダブルタップヒント文言（[ButtonActionHint] Step 7）。
abstract final class QuestionPromptListHints {
  static String get _lang => appSettings.language;

  static void showAdd(BuildContext context) => ButtonActionHint.show(
    context,
    tapText: '問題文一覧_ヒント_追加_タップ'.tr(_lang),
    longPressText: '問題文一覧_ヒント_追加_長押し'.tr(_lang),
  );

  static void showFilter(BuildContext context) => ButtonActionHint.show(
    context,
    tapText: '問題文一覧_ヒント_フィルタ_タップ'.tr(_lang),
  );

  static void showRow(BuildContext context) => ButtonActionHint.show(
    context,
    tapText: '問題文一覧_ヒント_行_タップ'.tr(_lang),
    longPressText: '問題文一覧_ヒント_行_長押し'.tr(_lang),
  );

  static void showOverviewBody(BuildContext context) => ButtonActionHint.show(
    context,
    tapText: 'ボタンヒント_タップなし'.tr(_lang),
    longPressText: '問題文一覧_ヒント_行_長押し'.tr(_lang),
  );

  static void showOverviewSummary(BuildContext context) =>
      ButtonActionHint.show(
        context,
        tapText: '問題文横断一覧_ヒント_総評_タップ'.tr(_lang),
      );

  static void showOverviewLayer(BuildContext context) => ButtonActionHint.show(
    context,
    tapText: '問題文横断一覧_ヒント_レイヤー_タップ'.tr(_lang),
  );
}
