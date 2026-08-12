import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../services/long_article_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer1_question_prompt_detail_screen.dart';
import 'layer1_question_prompt_screen.dart';
import 'layer1_screen.dart';
import 'layer1_vocab_screen.dart';
import 'long_article_flow_screen.dart';
import 'long_article_list_screen.dart';
import 'long_article_start_choice_sheet.dart';

enum Layer1Mode { longReading, vocab, podcast, questionPrompt }

/// レイヤーⅠの入口。「語彙を増やす」（問題文解析／長文読解／語彙テスト）と
/// 「日本語に耳を慣らす」から選び、選択後にそれぞれの画面
/// （[Layer1QuestionPromptScreen]、[Layer1LongReadingScreen]、
/// [Layer1VocabScreen]、[Layer1Screen]）へ切り替える。
///
/// モードの保持:
/// - ヘッダーで他レイヤーへ移って戻っても、同じモードを維持する
/// - スタート画面へスワイプで閉じると[resetMode]で選択画面に戻る
/// - 画面内の「戻る」またはヘッダー「Ⅰ」の再タップでも選択画面に戻れる
class Layer1EntryScreen extends StatefulWidget {
  const Layer1EntryScreen({
    super.key,
    this.onModeChanged,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// モード選択／解除のたびに呼ぶ（[MainShell]がMiniPlayer表示を切り替える用）。
  final VoidCallback? onModeChanged;

  /// 「問題文解析」詳細画面のII/III/IV/Vボタンから
  /// [MainShellState.openPromptDetailInLayer]へ転送する（Step 2〜）。
  /// 対象レイヤーのトップ・一覧をスキップし、同じ問題文の詳細を直接開く。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 「問題文解析」詳細画面の常設[AppHeader]から[MainShellState.selectLayer]
  /// 相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 「問題文解析」詳細画面の常設[AppHeader]のいずれかのボタン長押しから、
  /// スタート画面（起動画面）へジャンプする導線として転送する
  /// （[MainShellState]の「下/右スワイプで閉じる」と同じ着地）。
  final VoidCallback? onGoToStart;

  @override
  State<Layer1EntryScreen> createState() => Layer1EntryScreenState();
}

class Layer1EntryScreenState extends State<Layer1EntryScreen> {
  Layer1Mode? _mode;
  final _podcastKey = GlobalKey<Layer1ScreenState>();
  final _vocabKey = GlobalKey<Layer1VocabScreenState>();
  final _questionPromptKey = GlobalKey<Layer1QuestionPromptScreenState>();

  /// 「一覧から選ぶ」で長文一覧から選んだ長文。[Layer1LongReadingScreen]に
  /// 渡し、キーワード入力・生成をスキップしていきなり読解画面から始める。
  LongArticle? _initialLongArticle;

  /// 現在のモード。未選択（3択表示中）ならnull。
  Layer1Mode? get mode => _mode;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず、3択画面が
    // 古い言語のまま表示され続ける（モードを選んでから離れて戻ると、その
    // 遷移の再描画で偶然反映されてしまい気づきにくい）。appSettingsの変更を
    // 直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  /// [MainShellState.selectLayer]から、ポッドキャストモードが選択済みの
  /// ときだけ転送する。未選択（モード選択画面を表示中）なら何もしない。
  Future<void> reloadLibrary() async {
    await _podcastKey.currentState?.reloadLibrary();
  }

  /// [MainShellState._selectLayer]がレイヤーⅠから離れる直前に呼ぶ。
  /// 語彙モードなら[Layer1VocabScreenState.pauseBackgroundActivity]へ転送する。
  /// Podcastモード（[Layer1ScreenState]）は現時点で再生中の停止を持たない
  /// （ミニプレイヤーで裏でも再生し続ける仕様のため）。
  Future<void> pauseBackgroundActivity() async {
    await _vocabKey.currentState?.pauseBackgroundActivity();
  }

  /// 選択済みのモードを解除し、3択画面へ戻す。
  void resetMode() {
    if (!mounted || _mode == null) return;
    setState(() {
      _mode = null;
      _initialLongArticle = null;
    });
    widget.onModeChanged?.call();
  }

  void _selectMode(Layer1Mode mode) {
    setState(() => _mode = mode);
    widget.onModeChanged?.call();
  }

  /// 詳細画面の常設[AppHeader]「Ⅰ」タップや、起動画面の横断一覧ヘッダーから
  /// 呼ぶ。現在のモードに関わらず、問題文解析一覧へ切り替える。
  void selectQuestionPromptMode() {
    setState(() => _mode = Layer1Mode.questionPrompt);
    widget.onModeChanged?.call();
  }

  /// 起動画面の横断一覧などから呼ばれる。トップ・一覧をスキップし、指定した
  /// 問題文のⅠ詳細を直接開く（[Layer2EntryScreenState.openPromptDetail]と同じ設計）。
  void openPromptDetail(String promptId) {
    setState(() => _mode = Layer1Mode.questionPrompt);
    widget.onModeChanged?.call();
    unawaited(_pushPromptDetail(promptId));
  }

  Future<void> _pushPromptDetail(String promptId) async {
    await Layer1QuestionPromptDetailScreen.push(
      context,
      promptIds: [promptId],
      initialIndex: 0,
      onOpenPromptDetail: widget.onOpenPromptDetail,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
    );
    await _questionPromptKey.currentState?.reload();
  }

  /// 「長文読解」タップ時の入口。長文一覧が空ならそのままキーワード入力画面
  /// （動線①）を開く。1件以上あれば「一覧から選ぶ／新規作成」を選んでもらい、
  /// 「一覧から選ぶ」なら長文一覧から選んだ長文で（動線②をスキップして）
  /// 始める（osmCogitoの`AppRootShellState._startNewSession`と同じ分岐）。
  Future<void> _onLongReadingTapped() async {
    final articles = await LongArticleService().loadArticles();
    if (!mounted) return;
    if (articles.isEmpty) {
      _selectMode(Layer1Mode.longReading);
      return;
    }

    final choice = await LongArticleStartChoiceSheet.show(context);
    if (!mounted || choice == null) return;
    if (choice == LongArticleStartMode.newArticle) {
      _selectMode(Layer1Mode.longReading);
      return;
    }

    final selected = await LongArticleListScreen.push(
      context,
      selectionMode: true,
    );
    if (!mounted || selected == null) return;
    _initialLongArticle = selected;
    _selectMode(Layer1Mode.longReading);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      null => _Layer1ModeSelect(
        onSelect: _selectMode,
        onLongReadingTap: _onLongReadingTapped,
      ),
      Layer1Mode.podcast => Layer1Screen(
        key: _podcastKey,
        onBackToModeSelect: resetMode,
      ),
      Layer1Mode.vocab => Layer1VocabScreen(
        key: _vocabKey,
        onBackToModeSelect: resetMode,
      ),
      Layer1Mode.longReading => Layer1LongReadingScreen(
        onBackToModeSelect: resetMode,
        initialArticle: _initialLongArticle,
      ),
      Layer1Mode.questionPrompt => Layer1QuestionPromptScreen(
        key: _questionPromptKey,
        onOpenPromptDetail: widget.onOpenPromptDetail,
        onSelectLayer: widget.onSelectLayer,
        onGoToStart: widget.onGoToStart,
      ),
    };
  }
}

/// レイヤーⅠのモード選択画面。起動画面（[LaunchScreen]）と同じトーンで、
/// カードの塗りは持たず、シーンの青地に白いアイコン・文字だけを浮かせる。
///
/// 「語彙を増やす」見出しの下に「問題文解析」「長文読解」「語彙テスト」、
/// 「日本語に耳を慣らす」見出しの下に「ポッドキャスト」を、それぞれ
/// アイコン＋ラベルの行として縦に並べる（Step 2で「問題文解析」を追加）。
class _Layer1ModeSelect extends StatelessWidget {
  const _Layer1ModeSelect({
    required this.onSelect,
    required this.onLongReadingTap,
  });

  final ValueChanged<Layer1Mode> onSelect;

  /// 「長文読解」タップ専用（長文一覧の有無で選択シートを挟むかを非同期で
  /// 判定するため、他の項目と違い[onSelect]を直接は使わない）。
  final VoidCallback onLongReadingTap;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            ModeSectionHeading(text: '語彙を増やす'.tr(lang)),
            ModeListTile(
              icon: Icons.checklist_rounded,
              label: '問題文解析'.tr(lang),
              onTap: () => onSelect(Layer1Mode.questionPrompt),
            ),
            ModeListTile(
              icon: Icons.article_rounded,
              label: '長文読解'.tr(lang),
              onTap: onLongReadingTap,
            ),
            ModeListTile(
              icon: Icons.style_rounded,
              label: '語彙テスト'.tr(lang),
              onTap: () => onSelect(Layer1Mode.vocab),
            ),
            const SizedBox(height: 32),
            ModeSectionHeading(text: '日本語に耳を慣らす'.tr(lang)),
            ModeListTile(
              icon: Icons.headphones_rounded,
              label: 'ポッドキャスト'.tr(lang),
              onTap: () => onSelect(Layer1Mode.podcast),
            ),
          ],
        ),
      ),
    );
  }
}
