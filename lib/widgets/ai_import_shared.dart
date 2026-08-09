import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_strings.dart';
import '../services/background_audio_keeper.dart';
import '../services/chrome_ai_round_trip.dart';
import '../theme/app_colors.dart';

/// 「Chrome AIで開く → 回答をコピー → 読み込む → 取り込む」動線、および
/// レイヤーⅤ／ダッシュボードの「送信 → 貼り付け」往復が共通で使う部品群。
/// 取り込み画面どうしはパーサ・ストレージ・プレビューなど対象ごとの構造が
/// 異なるため画面全体は共通化していないが、フェード遷移・クリア確認・
/// 件数行・クリップボード往復フロー（[AiImportFlowMixin]）とキープアライブ、
/// 見た目が同じカード部品はここへ切り出している。

/// 取り込み画面向け：クリップボードのプレーンテキストを trim して返す。空なら null。
Future<String?> readImportClipboard() => ChromeAiRoundTrip.readClipboardText();

/// 取り込み画面向け：外部ブラウザで URL を開く（プロンプトは URL に含まれる想定）。
Future<bool> launchImportUrl(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// 語彙／発音課題／お題の取り込み画面が共有するフェード遷移。
Future<void> pushAiImportScreen(BuildContext context, Widget screen) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 取り込み済みデータの削除確認ダイアログ（キャンセル／削除）。
Future<bool> confirmAiImportClear({
  required BuildContext context,
  required String lang,
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('キャンセル'.tr(lang)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('削除'.tr(lang), style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Android版で、Chromeへ切り替えている間もプロセスが破棄されないよう
/// 無音のキープアライブ再生を行うための`State` mixin。
/// [handleAppLifecycleState]を`didChangeAppLifecycleState`から呼ぶこと。
/// 取り込み画面・レイヤーⅤ・ダッシュボードで同じ実装を共有する。
mixin AiImportKeepAliveMixin<T extends StatefulWidget> on State<T> {
  bool _startedKeeperForSession = false;

  /// Chromeから画面へ戻ってきた直後に呼ばれる。
  /// クリップボードの再読込・自動貼り付けなどに使う。
  void onResumedFromExternalApp();

  Future<void> ensureKeepAliveForExternalApp() async {
    if (!Platform.isAndroid) return;
    if (BackgroundAudioKeeper.instance.isRunning) return;
    await BackgroundAudioKeeper.instance.start();
    _startedKeeperForSession = true;
  }

  void stopKeepAliveIfOwned() {
    if (!_startedKeeperForSession) return;
    _startedKeeperForSession = false;
    unawaited(BackgroundAudioKeeper.instance.stop());
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 復帰直後は UI を先に描画し、クリップボード・キープアライブは後から処理する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onResumedFromExternalApp();
      if (_startedKeeperForSession &&
          !BackgroundAudioKeeper.instance.isActuallyPlaying) {
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (!mounted || !_startedKeeperForSession) return;
          unawaited(BackgroundAudioKeeper.instance.recoverIfNeeded());
        });
      }
    });
  }
}

/// 取り込み画面の「クリップボード読み込み → Chrome AI で開く → 結果メッセージ」
/// フローを共有する。パーサ・ストレージ・プレビューは各画面側に残す。
///
/// [initState]/[dispose] はオーバーライドしない（Flutter の State mixin と
/// 衝突しやすいため）。画面側で次のように呼ぶこと:
/// - `initState`: `super.initState()` のあと [initAiImportFlow]
/// - `dispose`: [disposeAiImportFlow] のあと `super.dispose()`
///
/// [importTextController] の生成・破棄はこの mixin が所有する。画面側で
/// 別途 dispose しないこと。
mixin AiImportFlowMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver, AiImportKeepAliveMixin<T> {
  late final TextEditingController importTextController;

  bool openedAi = false;
  String? resultMessage;
  bool resultIsError = false;
  List<int>? importResultCounts;

  /// クリップボード／貼り付けテキストが AI 回答らしいか。
  bool looksLikeAiImport(String text);

  /// [applyImportText] 内の setState 中に呼ばれる。プレビュー用パース結果の
  /// 更新などに使う（コントローラへの代入は mixin 側が行う）。
  void onImportTextApplied(String text);

  /// 「Chrome AI で開く」用の検索 URL。
  Uri buildChromeAiUrl();

  /// 取り込み済み件数などの再読込。
  Future<void> loadImportCounts();

  /// クリップボード読み込み成功時のメッセージ（翻訳キー）。
  String get clipboardLoadedSuccessMessage =>
      'クリップボードから読み込みました。内容を確認して「取り込む」を押してください。';

  /// `super.initState()` の直後に呼ぶ。
  void initAiImportFlow() {
    importTextController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    unawaited(loadImportCounts());
    if (Platform.isAndroid) {
      unawaited(ensureKeepAliveForExternalApp());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadClipboardIfAvailable();
    });
  }

  /// `super.dispose()` の直前に呼ぶ。[importTextController] もここで破棄する。
  void disposeAiImportFlow() {
    stopKeepAliveIfOwned();
    WidgetsBinding.instance.removeObserver(this);
    importTextController.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  void onResumedFromExternalApp() {
    unawaited(
      loadClipboardIfAvailable(
        showMessage: importTextController.text.trim().isEmpty,
      ),
    );
  }

  Future<void> openChromeAi() async {
    // 初回起動が数百 ms かかりうるため待たない（待つと Chrome が開かないことがある）。
    unawaited(ensureKeepAliveForExternalApp());
    await launchImportUrl(buildChromeAiUrl());
    if (!mounted) return;
    setState(() => openedAi = true);
  }

  Future<void> loadClipboardIfAvailable({bool showMessage = false}) async {
    final text = await readImportClipboard();
    if (!mounted) return;

    if (text == null || !looksLikeAiImport(text)) {
      if (showMessage) {
        setImportResult(
          message:
              'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。',
          isError: true,
        );
      }
      return;
    }

    final alreadyLoaded = importTextController.text.trim() == text;
    applyImportText(text);
    if (!showMessage && alreadyLoaded) return;

    setImportResult(message: clipboardLoadedSuccessMessage);
  }

  void applyImportText(String text) {
    setState(() {
      importTextController.text = text;
      onImportTextApplied(text);
    });
  }

  Future<void> pasteFromClipboard() async {
    await loadClipboardIfAvailable(showMessage: true);
  }

  void setImportResult({
    String? message,
    bool isError = false,
    List<int>? counts,
  }) {
    setState(() {
      resultMessage = message;
      resultIsError = isError;
      importResultCounts = counts;
    });
  }

  String? localizedResultMessage(String lang) {
    final message = resultMessage;
    if (message == null) return null;
    final counts = importResultCounts;
    if (counts != null) {
      return message.trFmt(lang, [for (final c in counts) c.toString()]);
    }
    return message.tr(lang);
  }
}

/// ラベル＋「%lld 件」＋任意の削除ボタン行（語彙レベル／発音カテゴリなど）。
/// [onClear] が null のときは件数のみ表示する（お題サマリー行向け）。
class AiImportCountRow extends StatelessWidget {
  const AiImportCountRow({
    super.key,
    required this.lang,
    required this.label,
    required this.count,
    this.onClear,
    this.clearTooltip,
  });

  final String lang;
  final String label;
  final int count;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.textOnCardPrimary),
            ),
          ),
          Text(
            '%lld 件'.trFmt(lang, [count.toString()]),
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
          if (onClear != null)
            IconButton(
              onPressed: count > 0 ? onClear : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: count > 0 ? Colors.red : palette.textOnCardSecondary,
              tooltip: clearTooltip,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// 画面上部の「タイトル＋完了ボタン」行。
class AiImportHeader extends StatelessWidget {
  const AiImportHeader({super.key, required this.title, required this.lang});

  final String title;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: palette.textOnScenePrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.check_circle, color: palette.textOnScenePrimary),
            tooltip: '完了'.tr(lang),
          ),
        ],
      ),
    );
  }
}

/// カード共通の角丸・枠線・パディング。
class AiImportCard extends StatelessWidget {
  const AiImportCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: child,
    );
  }
}

/// 「Chrome AI用プロンプト」カード（プロンプト文言をそのまま選択・コピーできる）。
class AiImportPromptCard extends StatelessWidget {
  const AiImportPromptCard({
    super.key,
    required this.lang,
    required this.prompt,
  });

  final String lang;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return AiImportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: palette.textOnCardPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chrome AI 用プロンプト'.tr(lang),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '「Chrome AIで開く」をタップすると、この内容でGoogleのAIモード検索が開きます。回答をコピーして下の欄に貼り付けてください。'
                .tr(lang),
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.subpageBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              prompt,
              style: TextStyle(
                fontSize: 12,
                color: palette.textOnCardPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「AIの出力（確認・編集）」カード（貼り付けたテキストを確認・編集する欄）。
class AiImportPasteCard extends StatelessWidget {
  const AiImportPasteCard({
    super.key,
    required this.lang,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.instructionText,
  });

  final String lang;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final String? instructionText;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return AiImportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI の出力（確認・編集）'.tr(lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            instructionText ??
                'Chromeから戻るとクリップボードから自動で読み込みます。空のときは「クリップボードから読み込む」を使ってください。内容を確認・編集してから「取り込む」を押してください。'
                    .tr(lang),
            style: TextStyle(fontSize: 11, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            onChanged: onChanged,
            style: TextStyle(color: palette.textOnCardPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: palette.textOnCardSecondary),
              filled: true,
              fillColor: palette.subpageBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「Chrome AIで開く」「クリップボードから読み込む」「取り込む」の3ボタンで
/// 使う共通ボタン。
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? palette.accentColor : palette.cardBorder)
              : palette.subpageBackground,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: palette.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: filled
                  ? (enabled ? palette.onAccent : palette.textOnCardPrimary)
                  : (enabled
                        ? palette.accentColor
                        : palette.textOnCardSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: filled
                    ? (enabled ? palette.onAccent : palette.textOnCardPrimary)
                    : (enabled
                          ? palette.textOnCardPrimary
                          : palette.textOnCardSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
