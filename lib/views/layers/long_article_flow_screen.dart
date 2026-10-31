import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/long_article_vocab_translation_prompt.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../models/long_article_comprehension_check.dart';
import '../../models/long_article_generation_result.dart';
import '../../models/long_article_generation_settings.dart';
import '../../models/long_article_vocab_word.dart';
import '../../models/saved_vocabulary_check.dart';
import '../../models/vocabulary_entry.dart';
import '../../services/long_article_service.dart';
import 'layer1_vocab_screen.dart';
import 'long_article_comprehension_check_screen.dart';
import 'long_article_generate_screen.dart';
import 'long_article_keyword_screen.dart';
import 'long_article_reader_screen.dart';

enum _LongReadingPhase {
  keyword,
  generate,
  reading,
  comprehensionCheck,
  vocabTest,
}

/// レイヤーⅠ「長文読解」フロー本体。キーワード → Chrome AI生成・貼付 →
/// 読む（タップで単語帳登録）→（任意で訳付け）→ 長文一覧へ保存、という
/// 一連をNavigatorを使わず単一の状態切替で進める
/// （[Layer1EntryScreen]自身の2択/3択切替、osmCogitoの
/// `CogitoSessionShell`と同じ「単一の親がフェーズを切り替える」設計）。
///
/// osmCogitoの関連質問・日本語回答・セッションラウンド・中断セッションは
/// 移植しない。再訪のたびにキーワード入力からやり直しになる
/// （[Layer1EntryScreen]が他モードと同じくGlobalKeyを持たないため）。
class Layer1LongReadingScreen extends StatefulWidget {
  const Layer1LongReadingScreen({
    super.key,
    this.onBackToModeSelect,
    this.initialArticle,
  });

  /// レイヤーⅠの3択へ戻る（保存完了時にも呼ぶ）。
  final VoidCallback? onBackToModeSelect;

  /// [Layer1EntryScreenState]が「一覧から選ぶ」で長文一覧から選んだ長文。
  /// 渡されていればキーワード入力・生成をスキップし、いきなり読解画面から
  /// 始める（保存済みなので、終了時に再保存はしない）。
  final LongArticle? initialArticle;

  @override
  State<Layer1LongReadingScreen> createState() =>
      Layer1LongReadingScreenState();
}

class Layer1LongReadingScreenState extends State<Layer1LongReadingScreen> {
  late var _phase = widget.initialArticle == null
      ? _LongReadingPhase.keyword
      : _LongReadingPhase.reading;
  LongArticleGenerationSettings? _settings;
  late String? _articleBody = widget.initialArticle?.body;

  /// 生成AIレスポンス（または保存済み[LongArticle]）に同梱された1秒チェック。
  /// nullなら旧データ／旧レスポンスとしてクイズフェーズをスキップする。
  late LongArticleComprehensionCheck? _comprehensionCheck =
      widget.initialArticle?.comprehensionCheck;

  /// 生成AIレスポンス（または保存済み[LongArticle]）に同梱された語彙テスト用
  /// 単語（最大9語）。空なら旧データ／旧レスポンスとして語彙テストフェーズを
  /// スキップする。
  late List<LongArticleVocabWord> _vocabTestWords =
      widget.initialArticle?.vocabTestWords ?? const [];

  /// 新規フローで一度保存した長文（採点の書き戻し先として使う）。
  /// [widget.initialArticle]が非nullの場合は使わない（保存済みのそれを使う）。
  LongArticle? _savedArticle;

  /// [_LongReadingPhase.vocabTest]表示中に[Layer1VocabScreen]へ渡す長文
  /// （[_ensureSavedArticle]の結果。新規フローは保存確定後、
  /// [widget.initialArticle]の場合はそれ自身）。
  LongArticle? _vocabTestArticle;

  /// 1秒チェックで選んだ選択肢。未実施・スキップはnull。
  String? _comprehensionSelectedOption;

  void _onSettingsReady(LongArticleGenerationSettings settings) {
    setState(() {
      _settings = settings;
      _phase = _LongReadingPhase.generate;
    });
  }

  void _onArticleGenerated(LongArticleGenerationResult result) {
    setState(() {
      _articleBody = result.body;
      _comprehensionCheck = result.comprehensionCheck;
      _vocabTestWords = result.vocabTestWords;
      _phase = _LongReadingPhase.reading;
    });
  }

  /// 読解画面の「次へ」タップ時の分岐。1秒チェックがあればそのフェーズへ、
  /// 無くて語彙テスト用単語があれば語彙テストへ、どちらも無ければ
  /// （旧データ／旧AIレスポンス）従来どおり即終了する。
  void _onReadingFinished() {
    if (_comprehensionCheck != null) {
      setState(() => _phase = _LongReadingPhase.comprehensionCheck);
      return;
    }
    if (_vocabTestWords.isNotEmpty) {
      unawaited(_startVocabTest());
      return;
    }
    unawaited(_finish());
  }

  /// 1秒チェック完了時の分岐。語彙テスト用単語があればそちらへ、
  /// 無ければ即終了する。
  void _onComprehensionCheckFinished(String selectedOption) {
    _comprehensionSelectedOption = selectedOption;
    if (_vocabTestWords.isNotEmpty) {
      unawaited(_startVocabTest());
      return;
    }
    unawaited(_finish());
  }

  /// 語彙テスト保存用の1秒チェックスナップショット。チェック未実施ならnull。
  SavedComprehensionQuizResult? get _comprehensionQuizResult {
    final check = _comprehensionCheck;
    final selected = _comprehensionSelectedOption;
    if (check == null || selected == null) return null;
    return SavedComprehensionQuizResult(
      question: check.question,
      optionA: check.optionA,
      optionB: check.optionB,
      correctOption: check.correctOption,
      selectedOption: selected,
      isCorrect: selected == check.correctOption,
      explanationJa: check.explanationJa,
      explanationEn: check.explanationEn,
      explanationVi: check.explanationVi,
    );
  }

  /// 語彙テスト開始前に長文を確定保存する（採点の書き戻し先として
  /// [LongArticle.id]が要るため）。保存できたら[_LongReadingPhase.vocabTest]へ
  /// 進む。[widget.initialArticle]の場合は既に保存済みなので再保存しない。
  Future<void> _startVocabTest() async {
    final article = await _ensureSavedArticle();
    if (!mounted || article == null) return;
    setState(() {
      _vocabTestArticle = article;
      _phase = _LongReadingPhase.vocabTest;
    });
  }

  /// 新規フローはまだ保存していなければ[LongArticleService.addArticle]で
  /// 確定保存し（「長文を保存しました」案内もここで1回だけ出す）、以後は
  /// 同じ[LongArticle]を使い回して二重保存・二重案内を避ける。
  /// [widget.initialArticle]の場合は保存済みのそれをそのまま返す。
  Future<LongArticle?> _ensureSavedArticle() async {
    if (widget.initialArticle != null) return widget.initialArticle;
    final saved = _savedArticle;
    if (saved != null) return saved;
    final settings = _settings;
    final body = _articleBody;
    if (settings == null || body == null) return null;
    final updated = await LongArticleService().addArticle(
      title: settings.keyword,
      body: body,
      generationKeyword: settings.keyword,
      generationJlptLevel: settings.jlptLevel.storageKey,
      generationLength: settings.length.targetCharacterCount,
      comprehensionCheck: _comprehensionCheck,
      vocabTestWords: _vocabTestWords,
    );
    final newArticle = updated.first;
    _savedArticle = newArticle;
    if (!mounted) return newArticle;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('長文を保存しました_V案内'.tr(appSettings.language))),
    );
    return newArticle;
  }

  /// [article.vocabTestWords]を[Layer1VocabScreen.fixedEntries]用の
  /// [VocabularyEntry]へ変換する（出題数＝抽出数、最大9）。単語帳へは登録せず、
  /// あくまで出題用の一時オブジェクト（IDは長文IDから決定的に組み立てるだけで、
  /// 単語帳側のエントリとは無関係）。訳語は常にen/vi両方持つ
  /// [LongArticleVocabWord]から、現在の表示言語に対応する側を使う。
  List<VocabularyEntry> _vocabTestEntries(LongArticle article) {
    final lang = appSettings.language;
    final translationLang = LongArticleVocabTranslationPrompt.translationLangFor(
      lang,
    );
    final words = article.vocabTestWords;
    return [
      for (var i = 0; i < words.length; i++)
        VocabularyEntry(
          id: 'lavocab_${article.id}_$i',
          word: words[i].word,
          reading: words[i].reading,
          exampleSentence: words[i].example,
          translation: words[i].meaningFor(lang),
          translationLang: translationLang,
          createdAt: article.createdAt,
        ),
    ];
  }

  /// 長文一覧から選んだ既存の長文で始めたときは、既に保存済みなので
  /// 再保存せず3択へ戻るだけ（[LongArticleListScreen]の自前ブラウズと
  /// 同じく「複製しない」方針）。新規フローは、語彙テストを経由していれば
  /// [_startVocabTest]の時点で既に保存済みのため、ここでは追加保存しない
  /// （[_ensureSavedArticle]が二重保存・二重案内を避ける）。
  Future<void> _finish() async {
    if (widget.initialArticle != null) {
      widget.onBackToModeSelect?.call();
      return;
    }
    final saved = await _ensureSavedArticle();
    if (!mounted || saved == null) return;
    widget.onBackToModeSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _LongReadingPhase.keyword => LongArticleKeywordScreen(
        onNext: _onSettingsReady,
      ),
      _LongReadingPhase.generate => LongArticleGenerateScreen(
        settings: _settings!,
        onGenerated: _onArticleGenerated,
      ),
      _LongReadingPhase.reading => LongArticleReaderScreen(
        body: _articleBody!,
        onFinish: _onReadingFinished,
      ),
      _LongReadingPhase.comprehensionCheck =>
        LongArticleComprehensionCheckScreen(
          check: _comprehensionCheck!,
          onComplete: _onComprehensionCheckFinished,
          continuesToVocabTest: _vocabTestWords.isNotEmpty,
        ),
      _LongReadingPhase.vocabTest => Layer1VocabScreen(
        fixedEntries: _vocabTestEntries(_vocabTestArticle!),
        gradedLongArticle: _vocabTestArticle,
        comprehensionQuiz: _comprehensionQuizResult,
        onLongArticleGraded: _finish,
      ),
    };
  }
}
