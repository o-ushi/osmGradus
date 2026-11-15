import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../widgets/choice_sheet.dart';

/// お題を「AIで追加」「自分で追加」するか、JSONファイルで
/// 「ファイルをインポート」「エクスポート」するか（Step 10 / Step 13）。
enum TopicAddMethod { ai, manual, jsonImport, jsonExport }

/// レイヤーⅡ・Ⅲ・Ⅳの「＋」タップ共通の入口。
/// Chrome AI取り込みとJSONファイル取り込みはラベル・説明文で区別する。
class TopicAddChoiceSheet extends StatelessWidget {
  const TopicAddChoiceSheet({super.key});

  static Future<TopicAddMethod?> show(BuildContext context) {
    return showChoiceSheet<TopicAddMethod>(
      context,
      (_) => const TopicAddChoiceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return ChoiceSheet<TopicAddMethod>(
      title: 'お題を追加'.tr(lang),
      choices: [
        ChoiceItem(
          icon: Icons.auto_awesome,
          label: 'AIで追加'.tr(lang),
          subtitle: 'お題_追加_説明_AI'.tr(lang),
          value: TopicAddMethod.ai,
        ),
        ChoiceItem(
          icon: Icons.edit_note_rounded,
          label: '自分で追加'.tr(lang),
          subtitle: 'お題_追加_説明_手入力'.tr(lang),
          value: TopicAddMethod.manual,
        ),
        ChoiceItem(
          icon: Icons.download_outlined,
          label: 'ファイルをインポート'.tr(lang),
          subtitle: 'お題_追加_説明_ファイルインポート'.tr(lang),
          value: TopicAddMethod.jsonImport,
        ),
        ChoiceItem(
          icon: Icons.upload_outlined,
          label: 'エクスポート'.tr(lang),
          subtitle: 'お題_追加_説明_エクスポート'.tr(lang),
          value: TopicAddMethod.jsonExport,
        ),
      ],
    );
  }
}
