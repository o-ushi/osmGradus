import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/long_article_vocab_translation_prompt.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/vocabulary_entry.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/long_article_vocab_translation_parser.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/ghost_pill.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// 長文読解中に登録した単語（訳語未入力）へ、Chrome AIで読み・訳語・例文を
/// まとめて付ける画面。osmCogitoの`VocabularyEnrichScreen`（埋め込み表示）を
/// そのまま移植——チェックボックスでの選び直し、[ChromeAiSubmitMixin]による
/// 送信/貼り付けの単一ボタン、訳付け完了時の自動での呼び出し元復帰。
class LongArticleVocabEnrichScreen extends StatefulWidget {
  const LongArticleVocabEnrichScreen({
    super.key,
    required this.entryIds,
    this.autoSubmit = false,
  });

  /// 対象の単語帳エントリID（読解画面でタップ/長押し登録した語）。
  final List<String> entryIds;

  /// trueなら、初期ロード直後に（訳が未入力の語を選択した状態で）確認なしで
  /// Chrome AI送信まで自動的に進める。読解画面の「訳を付ける」長押し導線用
  /// （長押しは選び直し画面を経由せず直接Chrome AIへ進む「近道」。タップは
  /// 通常どおりこの画面でチェックボックスを確認してから送信する）。
  final bool autoSubmit;

  static Future<void> push(
    BuildContext context, {
    required List<String> entryIds,
    bool autoSubmit = false,
  }) {
    return pushAiImportScreen(
      context,
      LongArticleVocabEnrichScreen(entryIds: entryIds, autoSubmit: autoSubmit),
    );
  }

  @override
  State<LongArticleVocabEnrichScreen> createState() =>
      LongArticleVocabEnrichScreenState();
}

class LongArticleVocabEnrichScreenState
    extends State<LongArticleVocabEnrichScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, ChromeAiSubmitMixin {
  final _vocabularyService = VocabularyService();

  bool _loading = true;
  List<VocabularyEntry> _entries = [];
  Set<String> _selectedIds = {};
  List<VocabularyEntry> _pendingWords = [];
  String? _resultMessage;

  /// [widget.autoSubmit]を消費するフラグ。初回の[_loadEntries]完了時にだけ
  /// 送信をトリガーし、以降の再ロード（[_pasteAndApply]後の一覧更新など）
  /// では再送信しない。
  bool _autoSubmitPending = false;

  /// 訳付け完了メッセージを見せてから自動で呼び出し元へ戻るまでの間
  /// （テスト用に公開）。
  @visibleForTesting
  static const autoReturnDelay = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoSubmitPending = widget.autoSubmit;
    unawaited(_loadEntries());
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
      bodyKey: '長文読解_訳付け_Google送信確認_本文',
    );
  }

  @override
  void showChromeAiMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// [widget.entryIds]に含まれる語だけ（訳の有無を問わず）を対象にする。
  /// 初期チェックは訳が未入力の語だけ。
  Future<void> _loadEntries() async {
    final all = await _vocabularyService.loadEntries();
    final byId = {for (final entry in all) entry.id: entry};
    final entries = [
      for (final id in widget.entryIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _selectedIds = {
        for (final entry in entries)
          if (entry.translation.isEmpty) entry.id,
      };
      _loading = false;
    });
    if (_autoSubmitPending) {
      _autoSubmitPending = false;
      unawaited(_send());
    }
  }

  void _toggleSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      _selectedIds = selectAll ? _entries.map((e) => e.id).toSet() : {};
    });
  }

  Future<void> _send() async {
    final selected = _entries
        .where((entry) => _selectedIds.contains(entry.id))
        .toList();
    if (selected.isEmpty) return;
    _pendingWords = selected;
    final lang = appSettings.language;
    final plan = LongArticleVocabTranslationPrompt.buildLaunchPlan(
      words: selected,
      appLanguage: lang,
    );
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

      final result = LongArticleVocabTranslationParser.parse(text);
      final entries = result.entries;
      if (!result.isSuccess || entries == null) {
        showChromeAiMessage('長文読解_訳の解析できません'.tr(lang));
        return;
      }
      clearChromeAiPendingState();

      final translationLang = LongArticleVocabTranslationPrompt.translationLangFor(
        lang,
      );
      var updatedCount = 0;
      final pending = _pendingWords;
      for (var i = 0; i < pending.length && i < entries.length; i++) {
        final parsed = entries[i];
        if (parsed == null) continue;
        final word = pending[i];
        await _vocabularyService.updateEntry(
          word.id,
          word: word.word,
          reading: parsed.reading.isEmpty ? word.reading : parsed.reading,
          exampleSentence: parsed.exampleSentence,
          translation: parsed.translation,
          translationLang: translationLang,
          level: word.level,
        );
        updatedCount++;
      }
      _pendingWords = [];
      if (!mounted) return;
      setState(() {
        _resultMessage = '長文読解_訳を追加しました'.trFmt(lang, [
          updatedCount.toString(),
        ]);
      });
      await _loadEntries();

      // 訳付け完了を「N件を追加しました」で一瞬確認できる間を置いてから、
      // 自動的に読解画面へ戻る（ユーザーが完了に気づいて自分で「戻る」を
      // 押す手間を省く）。
      await Future.delayed(autoReturnDelay);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _onSubmitTap() =>
      chromeAiOnSubmitTap(onSend: _send, onPaste: _pasteAndApply);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;

    final canSubmit =
        !chromeAiActionInFlight &&
        (chromeAiAwaitingPaste || _selectedIds.isNotEmpty);

    final list = _loading
        ? const Center(child: CircularProgressIndicator())
        : _entries.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '長文読解_訳付け対象なし'.tr(lang),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnSceneSecondary,
                ),
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Text(
                '訳を付ける'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnScenePrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '長文読解_訳付け説明'.tr(lang),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textOnSceneSecondary,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value:
                    _entries.isNotEmpty &&
                    _selectedIds.length == _entries.length,
                onChanged: (value) => _toggleSelectAll(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                side: BorderSide(color: palette.textOnScenePrimary, width: 1.5),
                activeColor: palette.accentColor,
                checkColor: palette.onAccent,
                title: Text(
                  '全選択'.tr(lang),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.textOnScenePrimary,
                  ),
                ),
              ),
              Divider(color: palette.textOnSceneSecondary.withValues(alpha: 0.4)),
              for (final entry in _entries)
                CheckboxListTile(
                  key: ValueKey(entry.id),
                  value: _selectedIds.contains(entry.id),
                  onChanged: (value) =>
                      _toggleSelected(entry.id, value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  side: BorderSide(
                    color: palette.textOnScenePrimary,
                    width: 1.5,
                  ),
                  activeColor: palette.accentColor,
                  checkColor: palette.onAccent,
                  title: Text(
                    entry.word,
                    style: TextStyle(color: palette.textOnScenePrimary),
                  ),
                  subtitle: Text(
                    entry.translation,
                    style: TextStyle(color: palette.textOnSceneSecondary),
                  ),
                ),
            ],
          );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        stopKeepAliveIfOwned();
      },
      child: SwipeToCloseWrapper(
        child: Material(
          color: palette.scene,
          child: SafeArea(
            child: Column(
              children: [
                if (_resultMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _resultMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.accentColor,
                      ),
                    ),
                  ),
                Expanded(child: list),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GhostPill(
                          icon: Icons.arrow_back_rounded,
                          tooltip: '戻る'.tr(lang),
                          showBorder: false,
                          horizontalPadding: 0,
                          height: 84,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      if (_entries.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: GhostPill(
                            icon: chromeAiAwaitingPaste
                                ? Icons.content_paste_go_rounded
                                : Icons.translate_rounded,
                            tooltip:
                                (chromeAiAwaitingPaste ? '貼り付け' : '訳と例文を取得')
                                    .tr(lang),
                            showBorder: false,
                            horizontalPadding: 0,
                            height: 84,
                            enabled: canSubmit,
                            onTap: canSubmit ? _onSubmitTap : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 読み込んだ対象単語一覧（テスト用）。
  @visibleForTesting
  List<VocabularyEntry> get debugEntries => _entries;

  /// 現在チェックされているID（テスト用）。
  @visibleForTesting
  Set<String> get debugSelectedIds => _selectedIds;
}
