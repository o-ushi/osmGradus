import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import 'launch_screen.dart';
import 'main_shell.dart';
import 'startup_screen.dart';

/// アプリのルート。[StartupScreen]・[LaunchScreen]・[MainShell]を兄弟として
/// 保持し、Navigatorのpush/popではなく表示切り替えだけで行き来する。
///
/// 以前は[LaunchScreen]がレイヤータイルのタップごとに[MainShell]を
/// 新規にpushしていたため、スタート画面へ戻ってから同じレイヤーに戻ると
/// （前の[MainShell]インスタンスは既に破棄されているため）常に真っさらな
/// 状態から始まってしまっていた。ここでは[MainShell]を一度だけ生成し、
/// 以後はレイヤーの切り替え（[MainShellState.selectLayer]）と表示/非表示の
/// 切り替えのみを行うことで、[MainShell]自体・内部の5レイヤーの状態
/// （発音チェックの進行中セッション、レイヤーⅡで引いたお題など）を
/// スタート画面との往復で保持する。
class AppRootShell extends StatefulWidget {
  const AppRootShell({super.key});

  @override
  State<AppRootShell> createState() => _AppRootShellState();
}

class _AppRootShellState extends State<AppRootShell> {
  final _mainShellKey = GlobalKey<MainShellState>();

  /// [MainShell]をまだ一度も開いていなければ、遅延生成のためfalseのまま
  /// にしておく（アプリ起動直後にレイヤーⅠ〜Ⅴを全て組み立てるのを避ける）。
  bool _mainShellCreated = false;
  bool _showingMainShell = false;
  int _initialLayerIndex = 0;

  /// このプロセス起動中にスタートアップを出した／閉じた状態。
  /// 設定で再有効にしても、同じ起動セッションでは出し直さない
  /// （次回コールドスタートで表示する）。
  late bool _showingStartup = appSettings.showStartupScreen;

  void _openLayer(int index, {bool forceReset = false}) {
    if (_mainShellCreated) {
      _mainShellKey.currentState?.selectLayer(index, forceReset: forceReset);
    } else {
      // 初回生成時は全レイヤーとも既に真っさらなので、forceResetは無視してよい。
      _mainShellCreated = true;
      _initialLayerIndex = index;
    }
    setState(() => _showingMainShell = true);
  }

  /// 横断問題文一覧の詳細ヘッダーから。入口の2/3択を飛ばして問題文一覧を開く。
  void _openLayerInListMode(int index) {
    if (!_mainShellCreated) {
      _mainShellCreated = true;
      _initialLayerIndex = index;
    }
    setState(() => _showingMainShell = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainShellKey.currentState?.openPromptListInLayer(index);
    });
  }

  void _backToStart() {
    setState(() => _showingMainShell = false);
  }

  /// 起動画面の「戻る」から、閉じる直前の[MainShell]をレイヤー切替も
  /// モードリセットも行わずそのまま再表示する（[selectLayer]を経由しない
  /// ため、既に表示中だったレイヤーの状態には一切触れない）。
  void _resumeMainShell() {
    setState(() => _showingMainShell = true);
  }

  void _finishStartup(bool dontShowAgain) {
    if (dontShowAgain) {
      appSettings.showStartupScreen = false;
    }
    setState(() => _showingStartup = false);
  }

  /// レイヤー一覧画面（[LaunchScreen]）を左端からの右スワイプで閉じたときに
  /// 呼ぶ。設定の「スタートアップ画面」がONのときだけ[LaunchScreen]側から
  /// 渡されるため、ここでは条件を見ずにそのまま表示し直せばよい。
  void _showStartup() {
    setState(() => _showingStartup = true);
  }

  @override
  Widget build(BuildContext context) {
    // LaunchScreen自体は保持する状態を持たないため、表示のたびに作り直して構わない。
    // レイヤー選択タイルの数字（「Ⅱ」等）が[AppHeader]のタブ文言と同じ
    // 文字列のままツリーに同居してしまい、`find.text('Ⅱ')`のようなテスト用
    // finderが複数該当してあいまいになる。状態を保つ必要があるのは
    // [MainShell]側だけなので、そちらのみVisibility(maintainState: true)で
    // 保持する。
    return Stack(
      children: [
        if (!_showingMainShell && !_showingStartup)
          LaunchScreen(
            onOpenLayer: _openLayer,
            onOpenLayerInListMode: _openLayerInListMode,
            onShowStartup: _showStartup,
            onResume: _mainShellCreated ? _resumeMainShell : null,
          ),
        if (_mainShellCreated)
          Visibility(
            visible: _showingMainShell,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: MainShell(
              key: _mainShellKey,
              initialIndex: _initialLayerIndex,
              onClose: _backToStart,
            ),
          ),
        if (_showingStartup) StartupScreen(onContinue: _finishStartup),
      ],
    );
  }
}
