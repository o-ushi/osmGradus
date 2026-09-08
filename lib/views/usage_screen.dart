import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import '../widgets/language_flag_button.dart';

/// スタートアップの「はじめる」の後（および設定で有効なとき）に出す、
/// Chrome AIモードのコピーボタンの押し方と基本操作を教える画面。
/// [StartupScreen]と同型の「次回から表示しない」チェック・確定ボタンを持つ。
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key, required this.onContinue});

  /// [dontShowAgain]がtrueなら、呼び出し側で次回表示オフを保存する。
  final ValueChanged<bool> onContinue;

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;

    return Scaffold(
      backgroundColor: palette.scene,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: LanguageFlagButton(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '使い方_タイトル'.tr(lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: palette.textOnScenePrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/chrome_ai_copy_button.png',
                          width: double.infinity,
                          fit: BoxFit.contain,
                          semanticLabel: '使い方_コピー画像_説明'.tr(lang),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '使い方_コピー本文'.tr(lang),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '使い方_プラス長押し'.tr(lang),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '使い方_ダブルタップ'.tr(lang),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      InkWell(
                        onTap: () => setState(
                          () => _dontShowAgain = !_dontShowAgain,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _dontShowAgain,
                                  onChanged: (value) {
                                    setState(
                                      () => _dontShowAgain = value ?? false,
                                    );
                                  },
                                  side: BorderSide(
                                    color: palette.textOnScenePrimary,
                                    width: 1.5,
                                  ),
                                  fillColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(
                                      WidgetState.selected,
                                    )) {
                                      return palette.accentColor;
                                    }
                                    return Colors.transparent;
                                  }),
                                  checkColor: palette.onAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '次回から表示しない'.tr(lang),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: palette.textOnScenePrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => widget.onContinue(_dontShowAgain),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accentColor,
                          foregroundColor: palette.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'ホーム画面へ'.tr(lang),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
