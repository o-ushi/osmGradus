import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/long_article_ai_prompt.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article_generation_settings.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/long_article_response_parser.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';

/// 長文読解フローの生成・貼付画面。osmCogitoの`CogitoArticleGenerateScreen`
/// と同じく、画面表示と同時に送信フロー（同意ダイアログ→Chrome起動）へ
/// 自動的に進み、Chromeから戻ると自動でクリップボードを読み取って解析する。
/// 成功したらそのまま[onGenerated]で読解画面へ進む（手動の確認操作は無い）。
/// 同意で拒否された場合やコピーに失敗した場合だけ、ボタンから手動で再送信
/// できる。レイヤーⅠ・Ⅴ・ダッシュボードと同じ[ChromeAiSubmitMixin]を使う。
class LongArticleGenerateScreen extends StatefulWidget {
  const LongArticleGenerateScreen({
    super.key,
    required this.settings,
    required this.onGenerated,
  });

  final LongArticleGenerationSettings settings;

  /// 生成された本文を確定し、読解画面へ進む。
  final ValueChanged<String> onGenerated;

  @override
  State<LongArticleGenerateScreen> createState() =>
      _LongArticleGenerateScreenState();
}

class _LongArticleGenerateScreenState extends State<LongArticleGenerateScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, ChromeAiSubmitMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 「Chrome AIで生成」の手動タップを省略し、画面表示と同時に送信フロー
    // （同意ダイアログ→Chrome起動）へ進める。同意で拒否された場合や
    // コピーに失敗した場合は、下のボタンから手動で再送信できる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_send());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopKeepAliveIfOwned();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    unawaited(_pasteAndApply());
  }

  @override
  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: '長文読解_生成_Google送信確認_タイトル',
      bodyKey: '長文読解_生成_Google送信確認_本文',
    );
  }

  @override
  void showChromeAiMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final lang = appSettings.language;
    final plan = LongArticleAiPrompt.buildLaunchPlan(widget.settings);
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
    );
  }

  Future<void> _pasteAndApply() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      if (!mounted || text == null) return;

      final body = LongArticleResponseParser.parse(text);
      if (body == null) {
        showChromeAiMessage('長文読解_解析できません'.tr(lang));
        return;
      }
      clearChromeAiPendingState();
      widget.onGenerated(body);
    });
  }

  Future<void> _onSubmitTap() =>
      chromeAiOnSubmitTap(onSend: _send, onPaste: _pasteAndApply);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final awaitingPaste = chromeAiAwaitingPaste;

    return Material(
      color: palette.scene,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: palette.textOnSceneSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  '長文を生成'.tr(lang),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: palette.textOnScenePrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (awaitingPaste
                          ? '長文読解_文章生成説明_貼付待ち'
                          : '長文読解_文章生成説明_送信前')
                      .tr(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.textOnSceneSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: chromeAiActionInFlight ? null : _onSubmitTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentColor,
                      foregroundColor: palette.onAccent,
                      disabledBackgroundColor: palette.cardBorder,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      awaitingPaste
                          ? Icons.content_paste_go_rounded
                          : Icons.smart_toy_outlined,
                    ),
                    label: Text(
                      (awaitingPaste
                              ? '長文読解_文章生成ボタン_貼付'
                              : '長文読解_文章生成ボタン_送信')
                          .tr(lang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
