import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../widgets/ai_import_shared.dart';
import '../widgets/google_ai_send_consent_dialog.dart';
import 'chrome_ai_round_trip.dart';

/// 「送信 → Chrome AI → 貼り付け保存」の往復をレイヤーⅠ・Ⅴ・ダッシュボードで共有する。
///
/// ## 二重の in-flight フラグについて
/// - [chromeAiActionInFlight]：この mixin が管理する Chrome AI 送受信の排他。
///   [chromeAiSend] / [runChromeAiPaste] が立てる。
/// - 画面側の `_actionInFlight`：録音開始・サイコロ抽選・リセットなど、
///   Chrome AI 以外のローカル操作の排他。
///
/// **貼り付け保存では `_actionInFlight` で包まないこと。**
/// [runChromeAiPaste] がすでに [chromeAiActionInFlight] で排他しており、
/// 二重に包むと片方の finally で先に下がった瞬間に再入できてしまう。
mixin ChromeAiSubmitMixin<T extends StatefulWidget>
    on State<T>, AiImportKeepAliveMixin<T> {
  bool chromeAiActionInFlight = false;
  bool chromeAiAwaitingPaste = false;
  String? chromeAiPendingSentPrompt;
  String chromeAiPendingResponseLanguage = 'ja';

  void showChromeAiMessage(String message);

  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(context, languageCode: lang);
  }

  Future<void> chromeAiSend({
    required String lang,
    required String prompt,
    required Uri url,
    bool requiresClipboardPaste = false,
    VoidCallback? onBeforeAwaitingPaste,
  }) async {
    if (chromeAiActionInFlight || chromeAiAwaitingPaste) return;
    setState(() => chromeAiActionInFlight = true);
    try {
      final consented = await confirmChromeAiSend(lang);
      if (!consented || !mounted) return;

      unawaited(ensureKeepAliveForExternalApp());
      // URL に依頼全文が載る短いプロンプトでは、クリップボードへ依頼文を
      // 残さない（copyPromptToClipboard: false）。残すと、Chrome AI の
      // 回答コピーが失敗／遅延したときに依頼文のままを「貼り付け成功」と
      // 誤判定したり、未変化扱いで失敗したりしやすい。
      final launched = await ChromeAiRoundTrip.copyPromptAndLaunch(
        prompt: prompt,
        url: url,
        copyPromptToClipboard: requiresClipboardPaste,
      );
      if (!mounted) return;
      if (!launched) {
        stopKeepAliveIfOwned();
        showChromeAiMessage('Chrome AIを開けませんでした'.tr(lang));
        return;
      }
      if (requiresClipboardPaste) {
        showChromeAiMessage('Chrome AI_プロンプト貼り付け'.tr(lang));
      }
      onBeforeAwaitingPaste?.call();
      setState(() {
        chromeAiAwaitingPaste = true;
        chromeAiPendingResponseLanguage = lang;
        chromeAiPendingSentPrompt = prompt;
      });
    } finally {
      if (mounted) setState(() => chromeAiActionInFlight = false);
    }
  }

  Future<String?> readChromeAiPasteText() async {
    final text = (await ChromeAiRoundTrip.readClipboardText())?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// クリップボード読取＋未変化チェック。失敗/未変化ならnull。
  /// レイヤーⅠ・Ⅴの`_pasteAndSaveResult`が読み取り直後に必ず行う前段処理
  /// （読み取り失敗メッセージ・送信プロンプトのまま変化なしの判定）を共有する。
  Future<String?> consumeChromeAiPasteText(String lang) async {
    final text = await readChromeAiPasteText();
    if (text == null) {
      showChromeAiMessage('Chrome AIの解析結果を読み取れませんでした'.tr(lang));
      return null;
    }
    if (chromeAiPasteLooksUnchanged(text, lang)) return null;
    return text;
  }

  /// Chrome AIの貼り付け保存を[chromeAiActionInFlight]で排他実行する。
  /// 画面側の[_actionInFlight]と二重に囲まないこと（ダッシュボードと同じ理由）。
  Future<void> runChromeAiPaste(Future<void> Function() body) async {
    if (chromeAiActionInFlight) return;
    setState(() => chromeAiActionInFlight = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => chromeAiActionInFlight = false);
    }
  }

  bool chromeAiPasteLooksUnchanged(String text, String lang) {
    final sentPrompt = chromeAiPendingSentPrompt;
    if (sentPrompt == null) return false;
    if (!ChromeAiRoundTrip.isUnchangedSentPrompt(text, sentPrompt)) {
      return false;
    }
    showChromeAiMessage(
      'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。'
          .tr(lang),
    );
    return true;
  }

  void clearChromeAiPendingState({VoidCallback? onCleared}) {
    setState(() {
      chromeAiAwaitingPaste = false;
      chromeAiPendingSentPrompt = null;
    });
    onCleared?.call();
    stopKeepAliveIfOwned();
  }

  Future<void> chromeAiOnSubmitTap({
    required Future<void> Function() onSend,
    required Future<void> Function() onPaste,
  }) async {
    if (chromeAiAwaitingPaste) {
      await onPaste();
    } else {
      await onSend();
    }
  }
}
