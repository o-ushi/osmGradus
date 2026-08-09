import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../services/long_article_service.dart';
import '../../theme/app_colors.dart';
import 'layer1_screen.dart';
import 'layer1_vocab_screen.dart';
import 'long_article_flow_screen.dart';
import 'long_article_list_screen.dart';
import 'long_article_start_choice_sheet.dart';

enum Layer1Mode { longReading, vocab, podcast }

/// レイヤーⅠの入口。「語彙を増やす（長文読解／語彙テスト）」/「日本語に耳を
/// 慣らす」の3択を出し、選択後にそれぞれの画面（[Layer1LongReadingScreen]、
/// [Layer1VocabScreen]、[Layer1Screen]）へ切り替える。
///
/// モードの保持:
/// - ヘッダーで他レイヤーへ移って戻っても、同じモードを維持する
/// - スタート画面へスワイプで閉じると[resetMode]で3択に戻る
/// - 画面内の「戻る」またはヘッダー「Ⅰ」の再タップでも3択に戻れる
class Layer1EntryScreen extends StatefulWidget {
  const Layer1EntryScreen({super.key, this.onModeChanged});

  /// モード選択／解除のたびに呼ぶ（[MainShell]がMiniPlayer表示を切り替える用）。
  final VoidCallback? onModeChanged;

  @override
  State<Layer1EntryScreen> createState() => Layer1EntryScreenState();
}

class Layer1EntryScreenState extends State<Layer1EntryScreen> {
  Layer1Mode? _mode;
  final _podcastKey = GlobalKey<Layer1ScreenState>();
  final _vocabKey = GlobalKey<Layer1VocabScreenState>();

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
    };
  }
}

/// レイヤーⅠの3択画面。起動画面（[LaunchScreen]）と同じトーンで、
/// カードの塗りは持たず、シーンの青地に白いアイコン・文字だけを浮かせる。
///
/// 上段は「語彙を増やす」を見出しとし、その下に「長文読解」「語彙テスト」の
/// 選択可能な子を横に並べる。下段は従来どおり「日本語に耳を慣らす」
/// （Podcast）の単独選択肢。
class _Layer1ModeSelect extends StatelessWidget {
  const _Layer1ModeSelect({
    required this.onSelect,
    required this.onLongReadingTap,
  });

  final ValueChanged<Layer1Mode> onSelect;

  /// 「長文読解」タップ専用（長文一覧の有無で選択シートを挟むかを非同期で
  /// 判定するため、他の2択と違い[onSelect]を直接は使わない）。
  final VoidCallback onLongReadingTap;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '語彙を増やす'.tr(lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textOnSceneSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _Layer1ModeOption(
                            icon: Icons.article_rounded,
                            label: '長文読解'.tr(lang),
                            iconSize: 72,
                            fontSize: 18,
                            onTap: onLongReadingTap,
                          ),
                        ),
                        Container(
                          width: 1,
                          color: palette.textOnSceneSecondary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        Expanded(
                          child: _Layer1ModeOption(
                            icon: Icons.style_rounded,
                            label: '語彙テスト'.tr(lang),
                            iconSize: 72,
                            fontSize: 18,
                            onTap: () => onSelect(Layer1Mode.vocab),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: palette.textOnSceneSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _Layer1ModeOption(
                icon: Icons.headphones_rounded,
                label: '日本語に耳を慣らす'.tr(lang),
                onTap: () => onSelect(Layer1Mode.podcast),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Layer1ModeOption extends StatelessWidget {
  const _Layer1ModeOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconSize = 128,
    this.fontSize = 22,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: palette.textOnScenePrimary),
            const SizedBox(height: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: palette.textOnScenePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
