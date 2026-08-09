import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article.dart';
import '../../services/long_article_service.dart';
import '../../theme/app_colors.dart';
import 'layer5_long_reading_screen.dart';
import 'layer5_screen.dart';
import 'long_article_list_screen.dart';

enum Layer5Mode { short, long }

/// レイヤーⅤの入口。「短文」（既存の10問セッション）／「長文」
/// （長文一覧から選んだ1本を音読）の2択を出し、選択後に
/// それぞれの画面へ切り替える（[Layer1EntryScreen]と同じ、
/// Navigatorを使わない単一の状態切替の設計）。
///
/// モードの保持:
/// - ヘッダーで他レイヤーへ移って戻っても、同じモードを維持する
///   （[resetAttempt]は録音・セッションの一時停止のみで、モードは解除しない）
/// - ヘッダー「Ⅴ」の再タップで2択に戻れる（[resetMode]）
/// - 起動画面のレイヤータイル長押し「始めから始める」でも2択に戻る
///   （[resetToFresh]、[MainShellState._resetLayerToFresh]から呼ばれる）
class Layer5EntryScreen extends StatefulWidget {
  const Layer5EntryScreen({super.key});

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

  /// 現在のモード。未選択（2択表示中）ならnull。
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
      case null:
        break;
    }
  }

  /// 選択済みのモードを解除し、2択画面へ戻す（ヘッダー「Ⅴ」再タップ用）。
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
  /// 録音の中断が完了してから2択画面へ戻す（[MainShellState._resetLayerToFresh]
  /// から呼ばれる）。
  Future<void> resetToFresh() async {
    await resetAttempt();
    if (!mounted) return;
    setState(() {
      _mode = null;
      _longArticle = null;
    });
  }

  void _selectShort() => setState(() => _mode = Layer5Mode.short);

  /// 「長文」タップ：長文一覧から選んでもらい（ランダム選択はしない）、
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
          onSelectShort: _selectShort,
          onSelectLong: _selectLong,
        );
      case Layer5Mode.short:
        return Layer5Screen(key: _shortKey);
      case Layer5Mode.long:
        return Layer5LongReadingScreen(key: _longKey, article: _longArticle!);
    }
  }
}

/// レイヤーⅤの2択画面。[Layer1EntryScreen]の3択画面と同じトーンで、
/// カードの塗りは持たず、シーンの青地に白いアイコン・文字だけを浮かせる。
class _Layer5ModeSelect extends StatelessWidget {
  const _Layer5ModeSelect({
    required this.hasArticles,
    required this.loadingArticles,
    required this.onSelectShort,
    required this.onSelectLong,
  });

  final bool hasArticles;
  final bool loadingArticles;
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
        child: Row(
          children: [
            Expanded(
              child: _Layer5ModeOption(
                icon: Icons.short_text_rounded,
                label: 'レイヤーⅤ_短文'.tr(lang),
                onTap: onSelectShort,
              ),
            ),
            Container(
              width: 1,
              color: palette.textOnSceneSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _Layer5ModeOption(
                icon: Icons.article_rounded,
                label: 'レイヤーⅤ_長文'.tr(lang),
                enabled: longEnabled,
                caption: longEnabled ? null : 'レイヤーⅤ_長文_一覧なし'.tr(lang),
                onTap: onSelectLong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Layer5ModeOption extends StatelessWidget {
  const _Layer5ModeOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.caption,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// [enabled]がfalseのときだけ、下に小さく表示する案内文。
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final color = enabled
        ? palette.textOnScenePrimary
        : palette.textOnScenePrimary.withValues(alpha: 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 128, color: color),
            const SizedBox(height: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnSceneSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
