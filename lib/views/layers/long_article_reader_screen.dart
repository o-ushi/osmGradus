import 'package:flutter/material.dart';

import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import '../../widgets/long_article_action_row.dart';
import '../../widgets/tappable_japanese_text.dart';
import '../../widgets/vocabulary_sheet.dart';
import 'long_article_vocab_enrich_screen.dart';

/// 長文読解フローの読解画面。本文をタップで単語帳登録できる
/// ([TappableJapaneseText])。操作バーは[GenkiTransportRow]と同じ枠
/// （余白ゼロ・背景と枠線は透明・大アイコン）を流用した
/// [LongArticleActionRow]で、左から「訳を付ける」（登録語があるとき）／
/// 「単語帳」／「次へ」。osmCogitoの関連質問・日本語回答・セッションラウンドは
/// 移植しない。
class LongArticleReaderScreen extends StatefulWidget {
  const LongArticleReaderScreen({
    super.key,
    required this.body,
    required this.onFinish,
  });

  final String body;

  /// 「次へ」タップ時に呼ぶ（保存・3択への復帰は呼び出し元に任せる）。
  final VoidCallback onFinish;

  @override
  State<LongArticleReaderScreen> createState() =>
      LongArticleReaderScreenState();
}

class LongArticleReaderScreenState extends State<LongArticleReaderScreen> {
  final List<String> _registeredWordIds = [];
  final _textKey = GlobalKey<TappableJapaneseTextState>();

  void _onWordRegistered(String id) {
    setState(() => _registeredWordIds.add(id));
  }

  /// 長押しで登録が取り消された語を、「訳を付ける」の対象からも外す。
  void _onWordUnregistered(String id) {
    setState(() => _registeredWordIds.remove(id));
  }

  Future<void> _openEnrich() async {
    await LongArticleVocabEnrichScreen.push(
      context,
      entryIds: List.of(_registeredWordIds),
    );
    await _textKey.currentState?.reloadRegisteredWords();
  }

  /// 長押し：選び直し画面を経由せず、確認なしで直接Chrome AIへ進む。
  Future<void> _openEnrichAutoSubmit() async {
    await LongArticleVocabEnrichScreen.push(
      context,
      entryIds: List.of(_registeredWordIds),
      autoSubmit: true,
    );
    await _textKey.currentState?.reloadRegisteredWords();
  }

  Future<void> _openVocabulary() async {
    await VocabularySheet.show(context);
    await _textKey.currentState?.reloadRegisteredWords();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final hasRegisteredWords = _registeredWordIds.isNotEmpty;
    return Material(
      color: palette.scene,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: TappableJapaneseText(
                    key: _textKey,
                    text: widget.body,
                    onWordRegistered: _onWordRegistered,
                    onWordUnregistered: _onWordUnregistered,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: LongArticleActionRow(
                showEnrich: hasRegisteredWords,
                onEnrich: hasRegisteredWords ? _openEnrich : null,
                onEnrichLongPress: hasRegisteredWords
                    ? _openEnrichAutoSubmit
                    : null,
                onVocabulary: _openVocabulary,
                onNext: widget.onFinish,
                languageCode: lang,
                enableActionHints: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
