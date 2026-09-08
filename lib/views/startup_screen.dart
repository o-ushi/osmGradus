import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import '../widgets/language_flag_button.dart';

/// インストール直後（および設定で有効なとき）に出す案内画面。
/// アプリアイコン・アプリ名・ブランド説明・「次回から表示しない」チェックの順。
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, required this.onContinue});

  /// [dontShowAgain]がtrueなら、呼び出し側で次回表示オフを保存する。
  final ValueChanged<bool> onContinue;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // システム文字サイズの影響を受けず、常に1行で表示する。
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'osmGradus',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                softWrap: false,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: palette.textOnScenePrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'スタートアップ_説明'.tr(lang),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                color: palette.textOnSceneSecondary,
                              ),
                            ),
                            const SizedBox(height: 36),
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
                                            () => _dontShowAgain =
                                                value ?? false,
                                          );
                                        },
                                        side: BorderSide(
                                          color: palette.textOnScenePrimary,
                                          width: 1.5,
                                        ),
                                        fillColor:
                                            WidgetStateProperty.resolveWith((
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
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () =>
                                    widget.onContinue(_dontShowAgain),
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.accentColor,
                                  foregroundColor: palette.onAccent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'はじめる'.tr(lang),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
