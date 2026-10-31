import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import '../widgets/language_flag_button.dart';
import '../widgets/startup_bottom_bar.dart';
import '../widgets/swipe_to_close_wrapper.dart';

/// スタートアップの「はじめる」の後（および設定で有効なとき）に出す、
/// Chrome AIモードのコピーボタンの押し方と基本操作を教える画面。
/// [StartupScreen]と同型の「次回から表示しない」チェック・確定ボタンを
/// 画面下に固定する。
/// ボタンでの確定に加え、左端からの右スワイプでも（チェックを保存せず）
/// スタートアップへ戻れる（[onSwipeToStartup]）。
class UsageScreen extends StatefulWidget {
  const UsageScreen({
    super.key,
    required this.onContinue,
    this.onSwipeToStartup,
  });

  /// [dontShowAgain]がtrueなら、呼び出し側で次回表示オフを保存する。
  final ValueChanged<bool> onContinue;

  /// 左端からの右スワイプでスタートアップへ戻る操作。未指定なら
  /// [SwipeToCloseWrapper]自体を付けない（単体テスト等でのフォールバック）。
  final VoidCallback? onSwipeToStartup;

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

    final scaffold = AnnotatedRegion<SystemUiOverlayStyle>(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
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
                        child: ColoredBox(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/images/chrome_ai_copy_button.png',
                            width: double.infinity,
                            fit: BoxFit.contain,
                            semanticLabel: '使い方_コピー画像_説明'.tr(lang),
                          ),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // スタートアップと同じく、読み終えなくても進めるよう下部に固定する。
              StartupBottomBar(
                dontShowAgain: _dontShowAgain,
                onDontShowAgainChanged: (v) =>
                    setState(() => _dontShowAgain = v),
                label: 'ホーム画面へ'.tr(lang),
                onPressed: () => widget.onContinue(_dontShowAgain),
              ),
            ],
          ),
        ),
      ),
    );

    final onSwipeToStartup = widget.onSwipeToStartup;
    if (onSwipeToStartup == null) {
      return scaffold;
    }
    return SwipeToCloseWrapper(onClose: onSwipeToStartup, child: scaffold);
  }
}
