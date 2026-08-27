import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// レイヤーⅡ解答例の手動貼り付けシート。
///
/// Chrome AIのコピーボタンや、アプリの自動クリップボード読み取りが不安定な
/// ときでも、iOSの「テキスト欄を長押し→ペースト」なら確実に取り込める。
/// 「クリップボードから読み込む」はユーザー操作起点の読み取り（iOSの
/// ペースト許可ダイアログが出やすい）用。
class SampleAnswerPasteSheet extends StatefulWidget {
  const SampleAnswerPasteSheet({
    super.key,
    required this.initialValue,
  });

  final String initialValue;

  /// 保存する文字列（trim済み）を返す。キャンセル／閉じるはnull。
  static Future<String?> show(
    BuildContext context, {
    String initialValue = '',
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SampleAnswerPasteSheet(initialValue: initialValue),
    );
  }

  @override
  State<SampleAnswerPasteSheet> createState() => _SampleAnswerPasteSheetState();
}

class _SampleAnswerPasteSheetState extends State<SampleAnswerPasteSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  bool _readingClipboard = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadClipboard() async {
    if (_readingClipboard) return;
    setState(() => _readingClipboard = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'レイヤーⅡ_解答例_クリップボード空'.tr(appSettings.language),
            ),
          ),
        );
        return;
      }
      setState(() => _controller.text = text);
    } finally {
      if (mounted) setState(() => _readingClipboard = false);
    }
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
        child: SingleChildScrollView(
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
                'レイヤーⅡ_解答例_貼り付けタイトル'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'レイヤーⅡ_解答例_貼り付け説明'.tr(lang),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: palette.textOnCardSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 5,
                maxLines: 12,
                style: TextStyle(
                  color: palette.textOnCardPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'レイヤーⅡ_解答例_貼り付けヒント'.tr(lang),
                  hintStyle: TextStyle(color: palette.textOnCardSecondary),
                  filled: true,
                  fillColor: palette.subpageBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _readingClipboard ? null : _loadClipboard,
                  icon: _readingClipboard
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.content_paste_rounded, size: 18),
                  label: Text('レイヤーⅡ_解答例_クリップボード読込'.tr(lang)),
                ),
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
}
