import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// 1つのテキスト項目（要約・結論・理由・具体例など）をタップで入力する
/// 共通の下部シート。既存値を[TextField]に読み込み、「保存」で編集後の
/// 文字列（trim済み）をpopする。スワイプで閉じた／「キャンセル」ではnullをpopする。
class TextEditSheet extends StatefulWidget {
  const TextEditSheet({
    super.key,
    required this.title,
    required this.initialValue,
    this.hintText,
  });

  final String title;
  final String initialValue;
  final String? hintText;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initialValue,
    String? hintText,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TextEditSheet(
        title: title,
        initialValue: initialValue,
        hintText: hintText,
      ),
    );
  }

  @override
  State<TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              style: TextStyle(color: palette.textOnCardPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: palette.textOnCardSecondary),
                filled: true,
                fillColor: palette.subpageBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('キャンセル'.tr(lang)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                  child: Text('保存'.tr(lang)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
