import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show appSettings, audioHandler;
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/swipe_to_close_wrapper.dart';
import 'layers/layer1_entry_screen.dart';
import 'layers/layer2_screen.dart';
import 'layers/layer3_screen.dart';
import 'layers/layer4_screen.dart';
import 'layers/layer5_entry_screen.dart';
import 'layers/practice_layer_screen.dart';
import 'podcast/mini_player_bar.dart';

/// レイヤーⅠ〜Ⅴを内包するメインシェル。
///
/// ヘッダーの「Ⅰ」〜「Ⅴ」をタップすると、Navigator遷移を挟まず
/// [IndexedStack] の表示切り替えのみで即座にレイヤーを切り替える。
/// 画面を閉じる際は下スワイプ / 右スワイプ（[SwipeToCloseWrapper]）を使う。
///
/// [AppRootShell]がこのウィジェットのインスタンスを一度生成したら破棄せず
/// 保持し続けるため（表示/非表示の切り替えのみ）、[selectLayer]で外部から
/// 破棄せずにレイヤーを切り替えられるようStateクラスを公開している。
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0, this.onClose});

  final int initialIndex;

  /// 画面を閉じる操作（下/右スワイプ）時に呼ぶ。未指定の場合は
  /// [Navigator.pop]（[LaunchScreen]から直接pushされて使われる場合、
  /// すなわち[AppRootShell]を経由しないフォールバック時の挙動）。
  final VoidCallback? onClose;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  final _layer1Key = GlobalKey<Layer1EntryScreenState>();
  final _layer2Key = GlobalKey<Layer2ScreenState>();
  final _layer3Key = GlobalKey<PracticeLayerScreenState<Layer3Screen>>();
  final _layer4Key = GlobalKey<PracticeLayerScreenState<Layer4Screen>>();
  final _layer5Key = GlobalKey<Layer5EntryScreenState>();

  late final List<Widget> _layerScreens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _layerScreens = [
      Layer1EntryScreen(key: _layer1Key, onModeChanged: _onLayer1ModeChanged),
      Layer2Screen(key: _layer2Key),
      Layer3Screen(key: _layer3Key),
      Layer4Screen(key: _layer4Key),
      Layer5EntryScreen(key: _layer5Key),
    ];
    // [AppRootShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず、下端の
    // [MiniPlayerBar]等の表示が古い言語のままになる。appSettingsの変更を
    // 直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
  }

  void _onLayer1ModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  /// [SwipeToCloseWrapper]の右/下スワイプで呼ぶ。レイヤーⅠでモード
  /// （ポッドキャスト/語彙/長文読解）を選択済みでも、ここでは解除しない
  /// （起動画面からレイヤーⅠへ再訪すると、閉じたときの続きから再開できる。
  /// [selectLayer]の[fromStartScreen]を参照）。
  void _handleSwipeClose() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// [AppRootShell]がスタート画面のレイヤータイルをタップしたときに、
  /// この既存インスタンスを破棄せず呼び出す（[MainShell]自体・内部の
  /// 5レイヤーの状態を保ったまま対象レイヤーへ切り替える）。
  /// [forceReset]は起動画面のレイヤータイル長押し「始めから始める」から
  /// 渡される。trueなら対象レイヤーの進行状況（[_resetLayerToFresh]）を
  /// 破棄してから開く（タップ＝続きから、長押し＝最初から、を切り分ける）。
  void selectLayer(int index, {bool forceReset = false}) {
    _selectLayer(index, forceReset: forceReset, fromStartScreen: true);
    // 起動画面の＋から番組追加したあとも反映されるよう、Ⅰ表示時に再読込。
    if (index == 0) {
      unawaited(_layer1Key.currentState?.reloadLibrary());
    }
  }

  void _selectLayer(
    int index, {
    bool forceReset = false,
    bool fromStartScreen = false,
  }) {
    // レイヤーⅠ・Ⅴでモード選択済みのとき、ヘッダーの同じタブを再タップすると
    // 選択画面へ戻る（レイヤーⅠ：語彙⇔長文読解⇔Podcast、レイヤーⅤ：
    // 短文⇔長文の切替をスタート退出なしで行える）。レイヤーⅠの長文読解中は
    // 解除しない（キーワード入力・Chrome AI生成・読解中の単語登録など、
    // 選び直しでは復元できない進行中の作業があるため）。
    // [fromStartScreen]（起動画面のレイヤータイルタップ）のときは、
    // モードを一切解除せず常に続きから再開する——選択画面に戻すのは
    // [forceReset]（長押し）のときだけ。
    if (index == _currentIndex) {
      if (forceReset) {
        _resetLayerToFresh(index);
        setState(() {});
      } else if (!fromStartScreen) {
        if (index == 0 &&
            _layer1Key.currentState?.mode != Layer1Mode.longReading) {
          _layer1Key.currentState?.resetMode();
          setState(() {});
        } else if (index == 4) {
          _layer5Key.currentState?.resetMode();
          setState(() {});
        }
      }
      return;
    }
    // レイヤーⅠ（語彙モード）は録音・TTS・keep-aliveが裏でも動き続けるため、
    // 離れる瞬間に一時停止する（試験の進行状況はリセットせず残す）。
    // レイヤーⅢ・Ⅳ・Ⅴは読み上げ・カウントダウンが裏でも動き続けるため、
    // 離れる瞬間に「リセット」と同じ処理を呼んで止めておく
    // （レイヤーⅤはモードそのものは解除しない。[Layer5EntryScreenState.resetAttempt]参照）。
    switch (_currentIndex) {
      case 0:
        unawaited(_layer1Key.currentState?.pauseBackgroundActivity());
      case 2:
        unawaited(_layer3Key.currentState?.resetAttempt());
      case 3:
        unawaited(_layer4Key.currentState?.resetAttempt());
      case 4:
        unawaited(_layer5Key.currentState?.resetAttempt());
    }
    if (forceReset) {
      _resetLayerToFresh(index);
    }
    // レイヤーⅠで長文を新規作成／削除したあとにレイヤーⅤへ来ても、
    // 「長文」の選択可否（一覧の有無）が反映されるよう毎回読み直す。
    if (index == 4) {
      unawaited(_layer5Key.currentState?.refreshArticles());
    }
    setState(() => _currentIndex = index);
  }

  /// [index]のレイヤーを、進行中の状態を破棄した「最初から」の状態に戻す
  /// （起動画面のレイヤータイル長押し専用）。
  void _resetLayerToFresh(int index) {
    switch (index) {
      case 0:
        _layer1Key.currentState?.resetMode();
      case 1:
        _layer2Key.currentState?.resetDrawnTopic();
      case 2:
        unawaited(_layer3Key.currentState?.resetAttempt());
      case 3:
        unawaited(_layer4Key.currentState?.resetAttempt());
      case 4:
        unawaited(_layer5Key.currentState?.resetToFresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    // ミニプレイヤーはレイヤーⅠの「耳慣れ（Podcast）」モードのときだけ出す。
    // 語彙試験中や2択画面では出さない（音声がぶつからない／レイアウトも揃う）。
    final showMiniPlayer =
        _currentIndex == 0 &&
        _layer1Key.currentState?.mode == Layer1Mode.podcast;
    // bottomNavigationBarを渡すとScaffoldがbodyのbottom paddingを潰すため、
    // MiniPlayer表示時だけ外側のpadding.bottomを再注入して他レイヤーと揃える。
    final outerPadding = MediaQuery.paddingOf(context);
    return SwipeToCloseWrapper(
      onClose: _handleSwipeClose,
      child: Scaffold(
        backgroundColor: palette.scene,
        resizeToAvoidBottomInset: true,
        appBar: AppHeader(currentIndex: _currentIndex, onSelect: _selectLayer),
        body: Builder(
          builder: (bodyContext) {
            final bodyMediaQuery = MediaQuery.of(bodyContext);
            final body = IndexedStack(
              index: _currentIndex,
              // IndexedStackは非表示のレイヤーも常時マウントし続けるため、
              // TickerModeで裏に回ったレイヤーのAnimationController（レイヤーⅢの
              // PREP点滅等）を止めておく。止めないと非表示レイヤーのアニメーションが
              // 動き続け、無駄な描画コストに加えテストのpumpAndSettleも終わらなくなる。
              children: [
                for (var i = 0; i < _layerScreens.length; i++)
                  TickerMode(
                    enabled: i == _currentIndex,
                    child: _layerScreens[i],
                  ),
              ],
            );
            if (!showMiniPlayer) return body;
            return MediaQuery(
              data: bodyMediaQuery.copyWith(
                padding: bodyMediaQuery.padding.copyWith(
                  bottom: outerPadding.bottom,
                ),
              ),
              child: body,
            );
          },
        ),
        bottomNavigationBar: showMiniPlayer
            ? MiniPlayerBar(handler: audioHandler)
            : null,
      ),
    );
  }
}
