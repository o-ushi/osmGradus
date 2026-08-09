import 'package:flutter/material.dart';

import '../data/app_languages.dart';
import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// 現在の表示言語の国旗だけを見せるボタン。タップすると言語選択シートを開く。
/// [StartupScreen]など、設定画面を経由せず素早く言語を切り替えたい場面で使う。
class LanguageFlagButton extends StatelessWidget {
  const LanguageFlagButton({super.key});

  String get _currentFlag {
    for (final (code, _, flag) in appLanguages) {
      if (code == appSettings.language) return flag;
    }
    return appLanguages.first.$3;
  }

  Future<void> _openPicker(BuildContext context) {
    final palette = AppColors.current;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '言語'.tr(appSettings.language),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_currentFlag, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = appSettings.language;
    return SafeArea(
      top: false,
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
              '言語'.tr(lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final (code, name, flag) in appLanguages)
              _LanguageOptionRow(
                code: code,
                name: name,
                flag: flag,
                selected: lang == code,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    required this.code,
    required this.name,
    required this.flag,
    required this.selected,
  });

  final String code;
  final String name;
  final String flag;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: () {
        appSettings.language = code;
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: palette.accentColor),
          ],
        ),
      ),
    );
  }
}
