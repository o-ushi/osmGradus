import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import '../widgets/language_flag_button.dart';
import '../widgets/startup_bottom_bar.dart';

/// インストール直後（および設定で有効なとき）に出す案内画面。
/// アプリアイコン・アプリ名・ブランド説明をスクロールで並べ、
/// 「次回から表示しない」と「はじめる」は画面下に固定する。
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 濃いscene色の上ではステータスバーの文字（時刻・バッテリー）を白にする。
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.scene,
        body: SafeArea(
          child: Column(
            children: [
              // 国旗は言語の切り替えで描き直すため const にしない。
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: LanguageFlagButton(),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 説明を読み終えなくても始められるよう、下部に固定する
              // （osmNichinichiと同じ）。
              StartupBottomBar(
                dontShowAgain: _dontShowAgain,
                onDontShowAgainChanged: (v) =>
                    setState(() => _dontShowAgain = v),
                label: 'はじめる'.tr(lang),
                onPressed: () => widget.onContinue(_dontShowAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
