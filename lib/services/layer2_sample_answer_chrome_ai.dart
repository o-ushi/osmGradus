import 'dart:async';

import 'package:flutter/material.dart';

import '../data/layer2_sample_answer_ai_prompt_template.dart';
import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/question_prompt.dart';
import '../widgets/ai_import_shared.dart';
import '../widgets/google_ai_send_consent_dialog.dart';
import '../widgets/sample_answer_paste_sheet.dart';
import '../widgets/text_view_sheet.dart';
import 'chrome_ai_round_trip.dart';
import 'chrome_ai_submit_mixin.dart';

/// レイヤーⅡ「解答例」の送信→貼り付け→保存→表示を、一覧詳細
/// （`Layer2QuestionPromptDetailScreen`）と「ランダム」（`Layer2RandomScreen`）
/// で共有するmixin。[ChromeAiSubmitMixin]・[AiImportKeepAliveMixin]の
/// 送受信基盤に、この機能専用の同意文言・保存先を乗せたもの。
///
/// 取得の本命は[SampleAnswerPasteSheet]（テキスト欄への長押しペースト／
/// クリップボード読込ボタン）。Chromeのコピーボタンや自動クリップボード
/// 読み取りはベストエフォートで、失敗しても手動貼り付けで完了できる。
mixin Layer2SampleAnswerMixin<T extends StatefulWidget>
    on State<T>, AiImportKeepAliveMixin<T>, ChromeAiSubmitMixin<T> {
  /// 解答例の送信・貼り付け・表示対象の問題文。未確定
  /// （ランダムの未抽選時など）はnull。
  QuestionPrompt? get sampleAnswerPrompt;

  /// 取得した解答例テキストを保存し、[sampleAnswerPrompt]を
  /// 更新済みの[QuestionPrompt]に差し替える（画面側の状態更新も担う）。
  Future<void> saveSampleAnswer(String text);

  /// 復帰後の自動取り込み監視。貼り付け成功・画面破棄・待ち解除で止める。
  int _clipboardWatchGeneration = 0;

  @override
  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: 'レイヤーⅡ_解答例_Google送信確認_タイトル',
      bodyKey: 'レイヤーⅡ_解答例_Google送信確認_本文',
    );
  }

  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    // 自動読み取りはサイレント。失敗してもシートは出さない
    // （一瞬のアプリ切り替えでシートが開くと煩い）。ユーザーが貼り付け
    // アイコンを押したときに[SampleAnswerPasteSheet]へ進む。
    unawaited(_pasteSilentlyWithWatch());
  }

  Future<void> _pasteSilentlyWithWatch() async {
    final generation = ++_clipboardWatchGeneration;
    final saved = await _trySaveFromClipboard();
    if (saved ||
        !mounted ||
        !chromeAiAwaitingPaste ||
        generation != _clipboardWatchGeneration) {
      return;
    }

    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted ||
          !chromeAiAwaitingPaste ||
          generation != _clipboardWatchGeneration) {
        return;
      }
      if (chromeAiActionInFlight) continue;
      final text = await readChromeAiPasteText();
      if (text == null ||
          !isPlausibleSampleAnswer(
            text,
            sentPrompt: chromeAiPendingSentPrompt,
          )) {
        continue;
      }
      await _trySaveFromClipboard();
      return;
    }
  }

  Future<void> sendSampleAnswerToChromeAi() async {
    final prompt = sampleAnswerPrompt;
    if (prompt == null) return;
    final lang = appSettings.language;
    final plan = Layer2SampleAnswerAiPromptTemplate.buildLaunchPlan(
      prompt: prompt,
      lang: lang,
    );
    _clipboardWatchGeneration++;
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
      onBeforeAwaitingPaste: () {
        if (plan.requiresClipboardPaste) return;
        showChromeAiMessage('レイヤーⅡ_解答例_コピー案内'.tr(lang));
      },
    );
  }

  static const _clipboardRetryAttempts = 5;
  static const _clipboardRetryDelay = Duration(milliseconds: 400);

  Future<String?> _readClipboardTextWithRetry() async {
    for (var attempt = 0; attempt < _clipboardRetryAttempts; attempt++) {
      final text = await readChromeAiPasteText();
      if (text != null) return text;
      if (attempt < _clipboardRetryAttempts - 1) {
        await Future<void>.delayed(_clipboardRetryDelay);
      }
    }
    return null;
  }

  /// クリップボードの内容が「45秒模範解答」として保存してよいか。
  @visibleForTesting
  static bool isPlausibleSampleAnswer(String text, {String? sentPrompt}) {
    final trimmed = text.trim();
    if (trimmed.length < 20) return false;
    if (sentPrompt != null &&
        ChromeAiRoundTrip.isUnchangedSentPrompt(trimmed, sentPrompt)) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return false;
    }
    const promptMarkers = [
      '約45秒で話せる模範解答',
      'sample answer of about 45 seconds',
      'câu trả lời mẫu có độ dài nói',
      'プレーンテキストのみで回答',
      'Reply in plain text only',
      'Chỉ trả lời bằng văn bản thường',
    ];
    for (final marker in promptMarkers) {
      if (trimmed.contains(marker)) return false;
    }
    return true;
  }

  /// 手動貼り付け用。依頼文そのもの／URLだけは弾くが、短めの本文は許可する。
  @visibleForTesting
  static bool isAcceptableManualPaste(String text, {String? sentPrompt}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (sentPrompt != null &&
        ChromeAiRoundTrip.isUnchangedSentPrompt(trimmed, sentPrompt)) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return false;
    }
    const promptMarkers = [
      '約45秒で話せる模範解答',
      'sample answer of about 45 seconds',
      'câu trả lời mẫu có độ dài nói',
    ];
    for (final marker in promptMarkers) {
      if (trimmed.contains(marker)) return false;
    }
    return true;
  }

  /// クリップボードから自動保存を試みる。成功したらtrue。
  Future<bool> _trySaveFromClipboard() async {
    var saved = false;
    await runChromeAiPaste(() async {
      final text = await _readClipboardTextWithRetry();
      if (!mounted) return;
      if (text == null ||
          !isPlausibleSampleAnswer(
            text,
            sentPrompt: chromeAiPendingSentPrompt,
          )) {
        return;
      }
      _clipboardWatchGeneration++;
      await saveSampleAnswer(text);
      if (!mounted) return;
      clearChromeAiPendingState();
      saved = true;
    });
    return saved;
  }

  /// 手動タップ時の貼り付け。まず自動読み取りを試し、だめなら貼り付けシートを開く。
  Future<void> pasteSampleAnswer({bool silent = false}) async {
    final saved = await _trySaveFromClipboard();
    if (saved || silent || !mounted || !chromeAiAwaitingPaste) return;
    await _showManualPasteSheet();
  }

  Future<void> _showManualPasteSheet() async {
    final lang = appSettings.language;
    final clipboard = await readChromeAiPasteText();
    final initial =
        clipboard != null &&
            isAcceptableManualPaste(
              clipboard,
              sentPrompt: chromeAiPendingSentPrompt,
            )
        ? clipboard
        : '';

    if (!mounted) return;
    final edited = await SampleAnswerPasteSheet.show(
      context,
      initialValue: initial,
    );
    if (edited == null || !mounted) return;
    if (!isAcceptableManualPaste(
      edited,
      sentPrompt: chromeAiPendingSentPrompt,
    )) {
      showChromeAiMessage('レイヤーⅡ_解答例_貼り付け無効'.tr(lang));
      return;
    }
    _clipboardWatchGeneration++;
    await saveSampleAnswer(edited);
    if (!mounted) return;
    clearChromeAiPendingState();
  }

  /// 解答例アイコンのタップ挙動。
  /// 空、または貼り付け待ちなら送信／貼り付け、非空なら読み取り専用シートで表示。
  Future<void> onSampleAnswerTap() async {
    final prompt = sampleAnswerPrompt;
    if (prompt == null) return;
    if (prompt.sampleAnswer.isNotEmpty && !chromeAiAwaitingPaste) {
      await showSampleAnswerViewSheet(prompt.sampleAnswer);
      return;
    }
    await chromeAiOnSubmitTap(
      onSend: sendSampleAnswerToChromeAi,
      onPaste: pasteSampleAnswer,
    );
  }

  /// 取得済み時の長押し＝再取得。未取得時・往復中は何もしない。
  Future<void> onSampleAnswerLongPress() async {
    final prompt = sampleAnswerPrompt;
    if (prompt == null || prompt.sampleAnswer.isEmpty) return;
    if (chromeAiActionInFlight || chromeAiAwaitingPaste) return;
    await sendSampleAnswerToChromeAi();
  }

  Future<void> showSampleAnswerViewSheet(String text) =>
      showSampleAnswerReadOnlySheet(context, text);
}

/// 解答例を読み取り専用[TextViewSheet]で表示する（Step 6レビュー：
/// [Layer2SampleAnswerMixin.showSampleAnswerViewSheet]とレイヤーⅣ
/// （閲覧専用、送受信は持たない）で共有する表示ヘルパー）。
Future<void> showSampleAnswerReadOnlySheet(
  BuildContext context,
  String text,
) async {
  final lang = appSettings.language;
  await TextViewSheet.show(context, title: '解答例'.tr(lang), text: text);
}
