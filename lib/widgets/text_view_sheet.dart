import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// 1つのテキスト項目を読み取り専用で表示する共通の下部シート
/// （[TextEditSheet]の閲覧専用版。編集は不可、選択・コピーのみできる）。
class TextViewSheet extends StatelessWidget {
  const TextViewSheet({super.key, required this.title, required this.text});

  final String title;
  final String text;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String text,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TextViewSheet(title: title, text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      // 編集不可＝キーボードが出ないため、[TextEditSheet]と違い
      // viewInsets.bottom分の余白確保は不要。長文でも画面を超えないよう
      // 高さを上限で区切り、本文だけをスクロール可能にする
      // （[LayerHelpSheet]と同じ考え方）。
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: TextStyle(
                      color: palette.textOnCardPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('閉じる'.tr(lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
