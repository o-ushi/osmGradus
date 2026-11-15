import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../widgets/choice_sheet.dart';

/// 「長文読解」タップ時、長文一覧に保存済みの長文があるときだけ出す、
/// 「一覧から選ぶ」か「新規作成」かの選択シート（[TopicAddChoiceSheet]と
/// 同じ見た目・構造。osmCogitoの`CogitoNewSessionChoiceSheet`と同じ役割を
/// 移植した）。
enum LongArticleStartMode {
  /// 長文一覧から選んだ長文でそのまま読解を始める（キーワード入力・生成を
  /// スキップする）。
  fromSavedArticle,

  /// 通常どおりキーワード入力から始める。
  newArticle,
}

class LongArticleStartChoiceSheet extends StatelessWidget {
  const LongArticleStartChoiceSheet({super.key});

  static Future<LongArticleStartMode?> show(BuildContext context) {
    return showChoiceSheet<LongArticleStartMode>(
      context,
      (_) => const LongArticleStartChoiceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return ChoiceSheet<LongArticleStartMode>(
      title: '長文読解_開始選択_タイトル'.tr(lang),
      choices: [
        ChoiceItem(
          icon: Icons.menu_book_outlined,
          label: '長文読解_開始選択_一覧から選ぶ'.tr(lang),
          subtitle: '長文読解_開始選択_一覧から選ぶ_説明'.tr(lang),
          value: LongArticleStartMode.fromSavedArticle,
        ),
        ChoiceItem(
          icon: Icons.auto_awesome_rounded,
          label: '長文読解_開始選択_新規作成'.tr(lang),
          subtitle: '長文読解_開始選択_新規作成_説明'.tr(lang),
          value: LongArticleStartMode.newArticle,
        ),
      ],
    );
  }
}
