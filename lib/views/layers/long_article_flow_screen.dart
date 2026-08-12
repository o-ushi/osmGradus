import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../models/long_article_comprehension_check.dart';
import '../../models/long_article_generation_result.dart';
import '../../models/long_article_generation_settings.dart';
import '../../services/long_article_service.dart';
import 'long_article_comprehension_check_screen.dart';
import 'long_article_generate_screen.dart';
import 'long_article_keyword_screen.dart';
import 'long_article_reader_screen.dart';

enum _LongReadingPhase { keyword, generate, reading, comprehensionCheck }

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
      _phase = _LongReadingPhase.reading;
    });
  }

  /// 読解画面の「次へ」タップ時の分岐。1秒チェックがあればそのフェーズへ
  /// 進み、無ければ（旧データ／旧AIレスポンス）従来どおり即終了する。
  void _onReadingFinished() {
    if (_comprehensionCheck != null) {
      setState(() => _phase = _LongReadingPhase.comprehensionCheck);
      return;
    }
    unawaited(_finish());
  }

  /// 長文一覧から選んだ既存の長文で始めたときは、既に保存済みなので
  /// 再保存せず3択へ戻るだけ（[LongArticleListScreen]の自前ブラウズと
  /// 同じく「複製しない」方針）。
  Future<void> _finish() async {
    if (widget.initialArticle != null) {
      widget.onBackToModeSelect?.call();
      return;
    }
    final settings = _settings;
    final body = _articleBody;
    if (settings == null || body == null) return;
    await LongArticleService().addArticle(
      title: settings.keyword,
      body: body,
      generationKeyword: settings.keyword,
      generationJlptLevel: settings.jlptLevel.storageKey,
      generationLength: settings.length.targetCharacterCount,
      comprehensionCheck: _comprehensionCheck,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('長文を保存しました_V案内'.tr(appSettings.language))),
    );
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
          onComplete: _finish,
        ),
    };
  }
}
