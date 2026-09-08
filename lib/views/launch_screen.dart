import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../localization/gradus_l10n.dart';
import '../main.dart' show appSettings, topicSpeechReader, ttsSettings;
import '../navigation/app_routes.dart';
import '../services/gradus_backup_actions.dart';
import '../services/question_prompt_backup_actions.dart';
import '../theme/app_colors.dart';
import '../widgets/backup_scope_sheet.dart';
import '../widgets/gradus_more_actions_menu.dart';
import '../widgets/layer_list_tile.dart';
import '../widgets/swipe_to_close_wrapper.dart';
import '../widgets/vocabulary_sheet.dart';
import 'main_shell.dart';

/// アプリ起動時のレイヤー選択画面。
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({
    super.key,
    this.onOpenLayer,
    this.onOpenLayerInListMode,
    this.onSwipeFromHome,
    this.onResume,
  });

  /// レイヤーがタップまたは長押しされたときに呼ぶ。指定されていれば、
  /// この画面自身は画面遷移を行わず呼び出し元（[AppRootShell]）に委ねる。
  /// これは[MainShell]を毎回pushで生成し直すのではなく、一度生成した
  /// インスタンスを破棄せず表示だけ切り替えるためで、スタート画面へ
  /// 戻ってから同じレイヤーに戻ったときに進行中の状態
  /// （発音チェックのセッション、引いたお題など）が保持される。
  /// [forceReset]がtrue（タイルの長押し）のときは、その進行中の状態を
  /// 破棄して最初から始める。falseまたは未指定（タップ）なら続きから再開する。
  /// 未指定の場合は従来通りこの画面自身が[MainShell]をpushする
  /// （[AppRootShell]を経由しない単体利用向けのフォールバック）。
  final void Function(int index, {bool forceReset})? onOpenLayer;

  /// 横断問題文一覧の詳細ヘッダー「Ⅰ」〜「Ⅴ」から、入口の2/3択を飛ばして
  /// 問題文一覧モードでそのレイヤーを開く。
  final void Function(int index)? onOpenLayerInListMode;

  /// 左端からの右スワイプで呼ぶ。着地先（使い方画面かスタートアップ画面か）
  /// は呼び出し元（[AppRootShell]）が「使い方」フラグの現在値で決める。
  /// 設定の「スタートアップ画面」がONかつこれが指定されているときだけ
  /// [SwipeToCloseWrapper]を有効にする（OFFなら不要なため何もしない）。
  final VoidCallback? onSwipeFromHome;

  /// スワイプで閉じる直前の[MainShell]をそのまま（レイヤー切替もモード
  /// リセットも行わず）再表示する「戻る」操作。まだ一度もレイヤーを
  /// 開いていない（戻り先が無い）場合はnullを渡し、ボタン自体を出さない。
  final VoidCallback? onResume;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  void _openLayer(BuildContext context, int index, {bool forceReset = false}) {
    final onOpenLayer = widget.onOpenLayer;
    if (onOpenLayer != null) {
      onOpenLayer(index, forceReset: forceReset);
      return;
    }
    // [AppRootShell]を経由しないフォールバック時は毎回新規[MainShell]を
    // pushするため既に真っさらで、forceResetは無視してよい。
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MainShell(initialIndex: index),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final layers = LaunchLayers.items;

    final scaffold = Scaffold(
      backgroundColor: palette.scene,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  'コンセプトサブタイトル'.tr(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: palette.textOnSceneSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: layers.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: palette.textOnSceneSecondary.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    return LayerListTile(
                      numeral: layer.numeral,
                      title: layer.titleKey.tr(lang),
                      subtitle: layer.subtitleKey.tr(lang),
                      color: palette.layerColors[index],
                      onTap: () => _openLayer(context, index),
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _openLayer(context, index, forceReset: true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  '起動_操作ヒント'.tr(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnSceneSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _LaunchActionRow(
                lang: lang,
                onResume: widget.onResume,
                onOpenLayerInListMode: widget.onOpenLayerInListMode,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    final onSwipeFromHome = widget.onSwipeFromHome;
    if (!appSettings.showStartupScreen || onSwipeFromHome == null) {
      return scaffold;
    }
    return SwipeToCloseWrapper(onClose: onSwipeFromHome, child: scaffold);
  }
}

/// 起動画面下部：単語帳 / ダッシュボード / 問題文一覧 / •••（白アイコン・透明背景）。
/// Podcast・お題・発音課題の取り込みは、各レイヤー画面自身の「＋」
/// （長押しで操作方法を表示）に一本化したため、ここには置かない。
/// エクスポート・インポート・設定・ヘルプは低頻度の操作のため、•••から
/// 開くアイコンメニュー（[GradusMoreActionsMenu]）にまとめている
/// （osmGenkiの起動画面と同じ配置方式）。
class _LaunchActionRow extends StatefulWidget {
  const _LaunchActionRow({
    required this.lang,
    this.onResume,
    this.onOpenLayerInListMode,
  });

  final String lang;

  /// 非nullなら「戻る」（[Icons.arrow_back_rounded]）を単語帳の左に出す。
  final VoidCallback? onResume;

  /// 問題文一覧の詳細ヘッダーから、入口を飛ばして問題文一覧モードで開く。
  final void Function(int index)? onOpenLayerInListMode;

  @override
  State<_LaunchActionRow> createState() => _LaunchActionRowState();
}

class _LaunchActionRowState extends State<_LaunchActionRow> {
  final _moreButtonKey = GlobalKey();

  void _showMoreMenu(BuildContext context) {
    final box = _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final offset = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final lang = widget.lang;

    // 横は画面中央。縦は「…」ボタンの直上。
    // 極端に狭い端末だけ widthFor で縮めて横スクロールする。
    const margin = 12.0;
    final availableWidth = screen.width - margin * 2;
    final menuWidth = GradusMoreActionsMenu.widthFor(availableWidth);
    final left = (screen.width - menuWidth) / 2;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            bottom: screen.height - offset.dy + 6,
            child: GradusMoreActionsMenu(
              languageCode: lang,
              maxWidth: menuWidth,
              onTranscript: () {
                Navigator.pop(dialogContext);
                AppRoutes.openTranscript(context);
              },
              onExport: () {
                Navigator.pop(dialogContext);
                unawaited(_chooseScopeAndExport(context));
              },
              onImport: () {
                Navigator.pop(dialogContext);
                unawaited(_chooseScopeAndImport(context));
              },
              onSettings: () {
                Navigator.pop(dialogContext);
                AppRoutes.openSettings(
                  context,
                  settings: ttsSettings,
                  speechReader: topicSpeechReader,
                );
              },
              onHelp: () {
                Navigator.pop(dialogContext);
                AppRoutes.openHelp(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// エクスポート先で「問題のみ」／「全て」を選ばせてから、対応する処理へ渡す。
  Future<void> _chooseScopeAndExport(BuildContext context) async {
    final lang = widget.lang;
    final scope = await BackupScopeSheet.show(
      context,
      title: 'エクスポート範囲を選択'.tr(lang),
    );
    if (scope == null || !context.mounted) return;
    if (scope == BackupScope.questionPromptsOnly) {
      await exportQuestionPromptsData(context);
    } else {
      await exportGradusData(context);
    }
  }

  /// インポート先で「問題のみ」／「全て」を選ばせてから、対応する処理へ渡す。
  Future<void> _chooseScopeAndImport(BuildContext context) async {
    final lang = widget.lang;
    final scope = await BackupScopeSheet.show(
      context,
      title: 'インポート範囲を選択'.tr(lang),
    );
    if (scope == null || !context.mounted) return;
    if (scope == BackupScope.questionPromptsOnly) {
      await importQuestionPromptsData(context);
    } else {
      await importGradusData(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final onResume = widget.onResume;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (onResume != null)
          _LaunchIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '戻る'.tr(lang),
            onTap: onResume,
          ),
        _LaunchIconButton(
          icon: Icons.style_rounded,
          tooltip: '単語帳'.tr(lang),
          onTap: () => VocabularySheet.show(context),
        ),
        _LaunchIconButton(
          icon: Icons.space_dashboard_outlined,
          tooltip: 'ダッシュボード'.tr(lang),
          onTap: () => AppRoutes.openDashboard(context),
        ),
        _LaunchIconButton(
          icon: Icons.list_alt_rounded,
          tooltip: '問題文一覧'.tr(lang),
          onTap: () => AppRoutes.openQuestionPromptOverview(
            context,
            onOpenLayer: widget.onOpenLayerInListMode,
          ),
        ),
        _LaunchIconButton(
          key: _moreButtonKey,
          icon: Icons.more_horiz,
          tooltip: 'その他'.tr(lang),
          onTap: () => _showMoreMenu(context),
        ),
      ],
    );
  }
}

class _LaunchIconButton extends StatelessWidget {
  const _LaunchIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.current.textOnScenePrimary;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 26, color: iconColor),
          ),
        ),
      ),
    );
  }
}
