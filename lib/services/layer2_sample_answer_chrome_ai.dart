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
            stripSampleAnswerFollowUp(text),
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
      final raw = await _readClipboardTextWithRetry();
      if (!mounted || raw == null) return;
      final text = stripSampleAnswerFollowUp(raw);
      if (!isPlausibleSampleAnswer(
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
    final stripped = clipboard == null
        ? null
        : stripSampleAnswerFollowUp(clipboard);
    final initial =
        stripped != null &&
            isAcceptableManualPaste(
              stripped,
              sentPrompt: chromeAiPendingSentPrompt,
            )
        ? stripped
        : '';

    if (!mounted) return;
    final pasted = await SampleAnswerPasteSheet.show(
      context,
      initialValue: initial,
    );
    if (pasted == null || !mounted) return;
    final edited = stripSampleAnswerFollowUp(pasted);
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

/// 解答例を読み取り専用[TextViewSheet]で表示する。
/// [Layer2SampleAnswerMixin.showSampleAnswerViewSheet]（取得済みタップ時の
/// 表示分岐）が呼ぶ共有ヘルパーで、この mixin を使うⅡ・Ⅳどちらの画面でも
/// 同じ見た目になる（送信・貼り付け自体は mixin の別メソッドが担う）。
Future<void> showSampleAnswerReadOnlySheet(
  BuildContext context,
  String text,
) async {
  final lang = appSettings.language;
  await TextViewSheet.show(
    context,
    title: '解答例'.tr(lang),
    text: stripSampleAnswerFollowUp(text),
  );
}

/// 解答例の見出し行（`Layer2SampleAnswerAiPromptTemplate` が指示する4つ）。
const _sampleAnswerHeadings = {'[質問]', '[日本語]', '[Romaji]', '[ベトナム語]'};

/// 解答例テキストの末尾に Chrome AI が付け足す「続きの提案」
/// （「この模範解答のスピード調整や、よりフォーマルなビジネス表現への変更など、
/// さらに練習しやすいようにカスタマイズしましょうか？」の類）だけを除いて返す。
///
/// 見出しがあれば最後の見出しブロックの本文末尾だけを見る（`[日本語]` 内の
/// 疑問文で終わる発話など、前のブロックには触らない）。見出しの無い旧テキスト
/// は全体の末尾を見る。候補は末尾の1段落（空行区切り）、段落が1つなら最終行、
/// 1行なら最後の1文。候補を除くと本文が空になる場合は除かない。
/// 保存前（新規の貼り付け）と表示前（保存済みの古い文）の両方で呼ぶ。
String stripSampleAnswerFollowUp(String text) {
  final lines = text.trimRight().split('\n');
  var bodyStart = 0;
  for (var i = lines.length - 1; i >= 0; i--) {
    if (_sampleAnswerHeadings.contains(lines[i].trim())) {
      bodyStart = i + 1;
      break;
    }
  }
  final head = lines.sublist(0, bodyStart);
  final body = lines.sublist(bodyStart).join('\n');
  final kept = _stripTrailingFollowUp(body);
  if (kept == null) return text;
  return [...head, kept].join('\n');
}

/// [body] の末尾候補が続きの提案なら、それを除いた本文を返す。除かないならnull。
String? _stripTrailingFollowUp(String body) {
  final trimmed = body.trimRight();
  String? rest;
  String? candidate;

  final paragraphBreak = RegExp(r'\n[ \t\u3000]*\n').allMatches(trimmed);
  if (paragraphBreak.isNotEmpty) {
    final last = paragraphBreak.last;
    rest = trimmed.substring(0, last.start);
    candidate = trimmed.substring(last.end);
  } else if (trimmed.contains('\n')) {
    final index = trimmed.lastIndexOf('\n');
    rest = trimmed.substring(0, index);
    candidate = trimmed.substring(index + 1);
  } else {
    // 1行の中で本文に続く最後の1文。直前の文末記号の後ろを候補にする。
    final sentenceEnds = RegExp(
      r'[。．！？!?]|\.(?=\s)',
    ).allMatches(trimmed).toList();
    if (sentenceEnds.length >= 2) {
      final boundary = sentenceEnds[sentenceEnds.length - 2].end;
      rest = trimmed.substring(0, boundary);
      candidate = trimmed.substring(boundary);
    }
  }

  if (rest == null || candidate == null) return null;
  if (rest.trim().isEmpty || !isSampleAnswerFollowUp(candidate)) return null;
  return rest.trimRight();
}

/// [sentence] が模範解答の手直しを申し出る「続きの提案」か。
@visibleForTesting
bool isSampleAnswerFollowUp(String sentence) {
  final trimmed = sentence.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  bool hasAny(List<String> words) => words.any(lower.contains);

  const editWords = [
    'カスタマイズ',
    '調整',
    'フォーマル',
    'スピード',
    'ビジネス表現',
    'customize',
    'customise',
    'adjust',
    'more formal',
    'speed',
    'tùy chỉnh',
    'tuỳ chỉnh',
    'điều chỉnh',
    'trang trọng',
    'tốc độ',
  ];
  if (!hasAny(editWords)) return false;

  const offerWords = [
    'しましょうか',
    'ましょうか',
    'しますか',
    'いかがですか',
    'would you like',
    'do you want',
    'shall i',
    'should i',
    'bạn có muốn',
  ];
  const sampleWords = [
    '模範解答',
    '解答例',
    '練習',
    'sample',
    'answer',
    'practice',
    'câu trả lời mẫu',
    'luyện',
  ];
  const requestEndings = [
    'お申し付け',
    'お知らせください',
    'お気軽に',
    'let me know',
    'cho tôi biết',
  ];
  final isQuestion = trimmed.endsWith('？') || trimmed.endsWith('?');
  if (isQuestion) return hasAny(offerWords) || hasAny(sampleWords);
  return hasAny(requestEndings);
}
