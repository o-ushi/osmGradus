import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appSettings;
import '../theme/app_colors.dart';
import '../widgets/ipad_phone_scale.dart';
import 'launch_screen.dart';
import 'main_shell.dart';
import 'startup_screen.dart';
import 'usage_screen.dart';

/// アプリのルート。[StartupScreen]・[UsageScreen]・[LaunchScreen]・[MainShell]を
/// 兄弟として保持し、Navigatorのpush/popではなく表示切り替えだけで行き来する。
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

  /// 使い方画面の表示状態。コールドスタート直後は常にfalse
  /// （使い方だけを起動時に出す経路は作らない。スタートアップの
  /// 「はじめる」を経由したときだけtrueになる）。
  bool _showingUsage = false;

  /// 横向きの右ペイン。レイヤー内の画面遷移はホームを覆わない。
  final _rightNavKey = GlobalKey<NavigatorState>();
  final _rightPaneRootKey = GlobalKey();

  /// 横向きの左ペイン。問題文一覧はホームの上（左側）に積む。
  final _leftNavKey = GlobalKey<NavigatorState>();
  final _leftPaneRootKey = GlobalKey();

  /// 横向きの左ペインに、ホームの代わりに出すレイヤーの問題文一覧。
  final _leftPane = IpadLeftPaneController();
  final _rightPaneTicker = _RightPaneTicker();

  @override
  void dispose() {
    _rightPaneTicker.dispose();
    _leftPane.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _rightPaneTicker.ping();
  }

  /// 横向きで右ペインに設定などが積まれていれば閉じ、レイヤーを見せる。
  void _clearRightPane() {
    _rightNavKey.currentState?.popUntil((route) => route.isFirst);
    _leftNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _openLayer(int index, {bool forceReset = false}) {
    _clearRightPane();
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
    _clearRightPane();
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
    _rightNavKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _showingMainShell = false);
  }

  /// 起動画面の「戻る」から、閉じる直前の[MainShell]をレイヤー切替も
  /// モードリセットも行わずそのまま再表示する（[selectLayer]を経由しない
  /// ため、既に表示中だったレイヤーの状態には一切触れない）。
  void _resumeMainShell() {
    _clearRightPane();
    setState(() => _showingMainShell = true);
  }

  void _finishStartup(bool dontShowAgain) {
    // 「はじめる」の着地は使い方フラグのみを見る（仕様B）。チェックONだと
    // setter側の不変条件で保存値の使い方がfalseになるため、その前の値を
    // 見ておく（今セッションの着地を消さないため）。
    final showUsageNow = appSettings.showUsageScreen;
    if (dontShowAgain) {
      appSettings.showStartupScreen = false;
    }
    setState(() {
      _showingStartup = false;
      _showingUsage = showUsageNow;
    });
  }

  void _finishUsage(bool dontShowAgain) {
    if (dontShowAgain) {
      appSettings.showUsageScreen = false;
    }
    setState(() => _showingUsage = false);
  }

  /// 使い方画面を左端からの右スワイプで閉じたときに呼ぶ。「次回から表示
  /// しない」を確定していない（「ホーム画面へ」を押していない）ため、
  /// フラグは保存せずスタートアップへ戻るだけ。
  void _swipeUsageToStartup() {
    setState(() {
      _showingUsage = false;
      _showingStartup = true;
    });
  }

  /// レイヤー一覧画面（[LaunchScreen]）を左端からの右スワイプで閉じたときに
  /// 呼ぶ。設定の「スタートアップ画面」がONのときだけ[LaunchScreen]側から
  /// 渡される。着地先は現在値の「使い方」フラグで分岐する（仕様D）。
  void _onSwipeFromHome() {
    setState(() {
      if (appSettings.showUsageScreen) {
        _showingUsage = true;
      } else {
        _showingStartup = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ipadLandscapeSplit(MediaQuery.sizeOf(context))) {
      return Stack(
        children: [
          _landscapeBody(),
          _landscapeStatusBarBand(context),
          if (!_showingStartup && _showingUsage)
            UsageScreen(
              onContinue: _finishUsage,
              onSwipeToStartup: _swipeUsageToStartup,
            ),
          if (_showingStartup) StartupScreen(onContinue: _finishStartup),
        ],
      );
    }
    // LaunchScreen自体は保持する状態を持たないため、表示のたびに作り直して構わない。
    // レイヤー選択タイルの数字（「Ⅱ」等）が[AppHeader]のタブ文言と同じ
    // 文字列のままツリーに同居してしまい、`find.text('Ⅱ')`のようなテスト用
    // finderが複数該当してあいまいになる。状態を保つ必要があるのは
    // [MainShell]側だけなので、そちらのみVisibility(maintainState: true)で
    // 保持する。
    return Stack(
      children: [
        if (!_showingMainShell && !_showingStartup && !_showingUsage)
          LaunchScreen(
            onOpenLayer: _openLayer,
            onOpenLayerInListMode: _openLayerInListMode,
            onSwipeFromHome: _onSwipeFromHome,
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
        if (!_showingStartup && _showingUsage)
          UsageScreen(
            onContinue: _finishUsage,
            onSwipeToStartup: _swipeUsageToStartup,
          ),
        if (_showingStartup) StartupScreen(onContinue: _finishStartup),
      ],
    );
  }

  /// 横向き。左はいつもレイヤー一覧。右は開いているレイヤー。
  Widget _landscapeBody() {
    final palette = AppColors.current;
    return IpadSplitScope(
      rightPaneKey: _rightPaneRootKey,
      leftPaneKey: _leftPaneRootKey,
      leftPane: _leftPane,
      child: ColoredBox(
        color: palette.scene,
        child: Row(
          children: [
            Expanded(
              child: IpadSplitPane(
                keepLeftInset: true,
                child: Navigator(
                  key: _leftNavKey,
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    builder: (context) => ListenableBuilder(
                      listenable: Listenable.merge([
                        _rightPaneTicker,
                        _leftPane,
                      ]),
                      builder: (context, _) => KeyedSubtree(
                        key: _leftPaneRootKey,
                        child: _leftPaneBody(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: palette.cardBorder,
              child: const SizedBox(width: 1),
            ),
            Expanded(
              child: IpadSplitPane(
                keepLeftInset: false,
                child: Navigator(
                  key: _rightNavKey,
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    builder: (context) => ListenableBuilder(
                      listenable: _rightPaneTicker,
                      builder: (context, _) => KeyedSubtree(
                        key: _rightPaneRootKey,
                        child: _rightPaneBody(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 横向きのステータスバー。iOS は全幅で1色の文字しか出せないため、白文字に
  /// 固定し、右ペインの上端（設定・ヘルプなど明るい画面でも）はシーンの濃い色で
  /// 塗って読めるようにする。最前面に置くので、各画面の指定より優先される。
  Widget _landscapeStatusBarBand(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return const SizedBox.shrink();
    final palette = AppColors.current;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: top,
      child: IgnorePointer(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(child: SizedBox.expand()),
              const SizedBox(width: 1),
              // 子なしの ColoredBox は高さ0で何も塗らないため、帯の高さいっぱいに広げる。
              Expanded(
                child: ColoredBox(
                  color: palette.scene,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 左ペイン。ふだんはホーム。レイヤーの問題文一覧を開いている間はその一覧。
  Widget _leftPaneBody(BuildContext context) {
    final list = _leftPane.builder;
    if (list == null) {
      return LaunchScreen(
        onOpenLayer: _openLayer,
        onOpenLayerInListMode: _openLayerInListMode,
        onSwipeFromHome: _onSwipeFromHome,
        onResume: _mainShellCreated ? _resumeMainShell : null,
      );
    }
    final palette = AppColors.current;
    return Material(
      color: palette.scene,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: _backToStart,
              icon: Icon(Icons.home_rounded, color: palette.textOnScenePrimary),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: Builder(builder: list),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPaneBody() {
    return ColoredBox(
      color: AppColors.current.scene,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_mainShellCreated)
            Visibility(
              visible: _showingMainShell,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              // 隠れている間は左ペインの問題文一覧も引っ込める。
              child: IpadPaneVisibility(
                visible: _showingMainShell,
                child: MainShell(
                  key: _mainShellKey,
                  initialIndex: _initialLayerIndex,
                  onClose: _backToStart,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 右ペインの中身を、ナビゲータのルートを作り直さずに描き直す。
class _RightPaneTicker extends ChangeNotifier {
  void ping() => notifyListeners();
}
