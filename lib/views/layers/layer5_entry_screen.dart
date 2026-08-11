import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../services/long_article_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer5_long_reading_screen.dart';
import 'layer5_question_prompt_detail_screen.dart';
import 'layer5_question_prompt_screen.dart';
import 'layer5_screen.dart';
import 'long_article_list_screen.dart';

enum Layer5Mode { questionPrompt, short, long }

/// レイヤーⅤの入口。「問題文一覧から選ぶ（問題文一覧→発音チェック、Step 6）」／
/// 「ランダム」（既存の短文10問セッション、Step 5でラベル・アイコンを
/// レイヤーⅣの「ランダム」に揃えた）／「長文読み上げ」（長文一覧から
/// 選んだ1本を音読）の3択を出し、選択後にそれぞれの画面へ切り替える
/// （[Layer1EntryScreen]と同じ、Navigatorを使わない単一の状態切替の設計）。
///
/// モードの保持:
/// - ヘッダーで他レイヤーへ移って戻っても、同じモードを維持する
///   （[resetAttempt]は録音・セッションの一時停止のみで、モードは解除しない）
/// - ヘッダー「Ⅴ」の再タップで3択に戻れる（[resetMode]）
/// - 起動画面のレイヤータイル長押し「始めから始める」でも3択に戻る
///   （[resetToFresh]、[MainShellState._resetLayerToFresh]から呼ばれる）
class Layer5EntryScreen extends StatefulWidget {
  const Layer5EntryScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
    this.onGoToSummary,
  });

  /// レイヤーⅣの詳細画面の「V」ボタンから
  /// [MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  /// AI発音評価が届いた後の「総評」タップで、この問題文のIDを渡して呼ぶ
  /// （[MainShellState]が[QuestionPromptSummaryScreen]をpushする実体を持つ）。
  final void Function(String promptId)? onGoToSummary;

  @override
  State<Layer5EntryScreen> createState() => Layer5EntryScreenState();
}

class Layer5EntryScreenState extends State<Layer5EntryScreen> {
  Layer5Mode? _mode;
  LongArticle? _longArticle;
  List<LongArticle> _articles = const [];
  bool _loadingArticles = true;

  final _shortKey = GlobalKey<Layer5ScreenState>();
  final _longKey = GlobalKey<Layer5LongReadingScreenState>();
  final _questionPromptKey = GlobalKey<Layer5QuestionPromptScreenState>();

  /// 現在のモード。未選択（3択表示中）ならnull。
  Layer5Mode? get mode => _mode;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
    unawaited(_loadArticles());
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _loadArticles() async {
    final articles = await LongArticleService().loadArticles();
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loadingArticles = false;
    });
  }

  /// レイヤーⅠで長文を新規作成／削除したあとに再訪しても一覧の有無が
  /// 反映されるよう、[MainShellState._selectLayer]がレイヤーⅤへ切り替える
  /// たびに呼ぶ。
  Future<void> refreshArticles() => _loadArticles();

  /// [MainShellState._selectLayer]がレイヤーⅤから離れる直前、またはヘッダー
  /// 「Ⅴ」再タップの直前に呼ぶ。選択中のモードは解除せず、録音・セッションの
  /// 状態だけを安全に一時停止／初期化する。
  Future<void> resetAttempt() async {
    switch (_mode) {
      case Layer5Mode.short:
        await _shortKey.currentState?.resetAttempt();
      case Layer5Mode.long:
        await _longKey.currentState?.resetAttempt();
      case Layer5Mode.questionPrompt:
        break;
      case null:
        break;
    }
  }

  /// 選択済みのモードを解除し、3択画面へ戻す（ヘッダー「Ⅴ」再タップ用）。
  /// 録音中であれば[resetAttempt]で安全に中断してから戻す。
  void resetMode() {
    if (!mounted || _mode == null) return;
    unawaited(resetAttempt());
    setState(() {
      _mode = null;
      _longArticle = null;
    });
  }

  /// 起動画面のレイヤータイル長押し「始めから始める」用。[resetMode]と違い、
  /// 録音の中断が完了してから3択画面へ戻す（[MainShellState._resetLayerToFresh]
  /// から呼ばれる）。
  Future<void> resetToFresh() async {
    await resetAttempt();
    if (!mounted) return;
    setState(() {
      _mode = null;
      _longArticle = null;
    });
  }

  void _selectMode(Layer5Mode mode) => setState(() => _mode = mode);

  /// 詳細画面の常設[AppHeader]「Ⅴ」タップから呼ぶ
  /// （[MainShellState._headerSelectLayer]参照）。常に問題文一覧へ切り替える。
  void selectListMode() => _selectMode(Layer5Mode.questionPrompt);

  /// レイヤーⅣの「V」から呼ばれる。トップ・一覧をスキップし、指定した
  /// 問題文のⅤ詳細を直接開く。
  ///
  /// [_mode]を`questionPrompt`に切り替えるだけでは、既に`questionPrompt`に
  /// なっている場合[Layer5QuestionPromptScreen]が使い回され、
  /// [State.initState]は再実行されない。そのため、一覧が新規生成されたかに
  /// 関わらず、ここで確実に[Layer5QuestionPromptDetailScreen]を直接pushする
  /// （[Layer4EntryScreenState.openPromptDetail]と同じ設計）。
  void openPromptDetail(String promptId) {
    setState(() => _mode = Layer5Mode.questionPrompt);
    unawaited(_pushPromptDetail(promptId));
  }

  Future<void> _pushPromptDetail(String promptId) async {
    await Layer5QuestionPromptDetailScreen.push(
      context,
      promptIds: [promptId],
      initialIndex: 0,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
      onGoToSummary: widget.onGoToSummary,
    );
    await _questionPromptKey.currentState?.reload();
  }

  /// 「長文読み上げ」タップ：長文一覧から選んでもらい（ランダム選択はしない）、
  /// 選んだ長文で音読画面を開く。
  void _selectLong() {
    unawaited(_pickLongFromList());
  }

  Future<void> _pickLongFromList() async {
    final selected = await LongArticleListScreen.push(
      context,
      selectionMode: true,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _longArticle = selected;
      _mode = Layer5Mode.long;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case null:
        return _Layer5ModeSelect(
          hasArticles: _articles.isNotEmpty,
          loadingArticles: _loadingArticles,
          onSelectQuestionPrompt: () => _selectMode(Layer5Mode.questionPrompt),
          onSelectShort: () => _selectMode(Layer5Mode.short),
          onSelectLong: _selectLong,
        );
      case Layer5Mode.questionPrompt:
        return Layer5QuestionPromptScreen(
          key: _questionPromptKey,
          onSelectLayer: widget.onSelectLayer,
          onGoToStart: widget.onGoToStart,
          onGoToSummary: widget.onGoToSummary,
        );
      case Layer5Mode.short:
        return Layer5Screen(key: _shortKey);
      case Layer5Mode.long:
        return Layer5LongReadingScreen(key: _longKey, article: _longArticle!);
    }
  }
}

/// レイヤーⅤの3択画面。[Layer1EntryScreen]の3択画面と同じ、シーンの青地に
/// アイコン＋ラベルの行を縦に並べるトーン。
class _Layer5ModeSelect extends StatelessWidget {
  const _Layer5ModeSelect({
    required this.hasArticles,
    required this.loadingArticles,
    required this.onSelectQuestionPrompt,
    required this.onSelectShort,
    required this.onSelectLong,
  });

  final bool hasArticles;
  final bool loadingArticles;
  final VoidCallback onSelectQuestionPrompt;
  final VoidCallback onSelectShort;
  final VoidCallback onSelectLong;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final longEnabled = hasArticles && !loadingArticles;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            ModeListTile(
              icon: Icons.checklist_rounded,
              label: '問題文一覧から選ぶ'.tr(lang),
              onTap: onSelectQuestionPrompt,
            ),
            ModeListTile(
              icon: Icons.casino_rounded,
              label: 'レイヤーⅤ_短文'.tr(lang),
              onTap: onSelectShort,
            ),
            ModeListTile(
              icon: Icons.article_rounded,
              label: 'レイヤーⅤ_長文'.tr(lang),
              enabled: longEnabled,
              caption: longEnabled ? null : 'レイヤーⅤ_長文_一覧なし'.tr(lang),
              onTap: onSelectLong,
            ),
          ],
        ),
      ),
    );
  }
}
