import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer4_question_prompt_detail_screen.dart';
import 'layer4_question_prompt_screen.dart';
import 'layer4_screen.dart';
import 'practice_layer_screen.dart';

enum Layer4Mode { selectFromList, random }

/// レイヤーⅣの入口（Step 5）。「問題文一覧から選ぶ（問題文一覧→JSST採点）」／
/// 「ランダム」（既存の[Layer4Screen]：サイコロ抽選・タイマー・録音・採点）の
/// 2択を出す。[Layer3EntryScreen]と同じモード保持・スキップ遷移の考え方を踏襲する。
class Layer4EntryScreen extends StatefulWidget {
  const Layer4EntryScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// レイヤーⅢ・Ⅴの詳細画面のIV・Vボタンから
  /// [MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer4EntryScreen> createState() => Layer4EntryScreenState();
}

class Layer4EntryScreenState extends State<Layer4EntryScreen> {
  Layer4Mode? _mode;
  final _randomKey = GlobalKey<PracticeLayerScreenState<Layer4Screen>>();
  final _questionPromptKey = GlobalKey<Layer4QuestionPromptScreenState>();

  Layer4Mode? get mode => _mode;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず、2択画面が
    // 古い言語のまま表示され続ける。appSettingsの変更を直接購読し、
    // その場で再描画する（[Layer1EntryScreenState]と同じ理由）。
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  void _selectMode(Layer4Mode mode) {
    setState(() => _mode = mode);
  }

  /// 選択済みのモードを解除し、2択画面へ戻す
  /// （ヘッダー「Ⅳ」再タップ・「始めから始める」長押しから呼ぶ）。
  void resetMode() {
    if (!mounted || _mode == null) return;
    setState(() => _mode = null);
  }

  /// 詳細画面の常設[AppHeader]「Ⅳ」タップから呼ぶ
  /// （[MainShellState._headerSelectLayer]参照）。常に問題文一覧へ切り替える。
  void selectListMode() => _selectMode(Layer4Mode.selectFromList);

  /// [MainShellState._selectLayer]がレイヤーⅣから離れる直前に呼ぶ。
  /// 「ランダム」モード（既存[Layer4Screen]）が裏で読み上げ・カウントダウン・
  /// 録音を動かし続けないよう止める（[Layer4ScreenState]が未マウントなら無視）。
  Future<void> resetAttempt() async {
    await _randomKey.currentState?.resetAttempt();
  }

  /// レイヤーⅢの「IV」から呼ばれる。トップ・一覧をスキップし、指定した
  /// 問題文のⅣ詳細を直接開く。
  ///
  /// [_mode]を`selectFromList`に切り替えるだけでは、既に`selectFromList`に
  /// なっている場合[Layer4QuestionPromptScreen]が使い回され、
  /// [State.initState]は再実行されない。そのため、一覧が新規生成されたかに
  /// 関わらず、ここで確実に[Layer4QuestionPromptDetailScreen]を直接pushする
  /// （[Layer3EntryScreenState.openPromptDetail]と同じ設計）。
  void openPromptDetail(String promptId) {
    setState(() => _mode = Layer4Mode.selectFromList);
    unawaited(_pushPromptDetail(promptId));
  }

  Future<void> _pushPromptDetail(String promptId) async {
    await Layer4QuestionPromptDetailScreen.push(
      context,
      promptIds: [promptId],
      initialIndex: 0,
      onOpenPromptDetail: widget.onOpenPromptDetail,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
    );
    await _questionPromptKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      null => _Layer4ModeSelect(onSelect: _selectMode),
      Layer4Mode.random => Layer4Screen(key: _randomKey),
      Layer4Mode.selectFromList => Layer4QuestionPromptScreen(
        key: _questionPromptKey,
        onOpenPromptDetail: widget.onOpenPromptDetail,
        onSelectLayer: widget.onSelectLayer,
        onGoToStart: widget.onGoToStart,
      ),
    };
  }
}

/// レイヤーⅣの2択画面。[Layer3EntryScreen]の2択画面と同じ、シーンの青地に
/// アイコン＋ラベルの行を縦に並べるトーン。
class _Layer4ModeSelect extends StatelessWidget {
  const _Layer4ModeSelect({required this.onSelect});

  final ValueChanged<Layer4Mode> onSelect;

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
            ModeListTile(
              icon: Icons.checklist_rounded,
              label: '問題文一覧から選ぶ'.tr(lang),
              onTap: () => onSelect(Layer4Mode.selectFromList),
            ),
            ModeListTile(
              icon: Icons.casino_rounded,
              label: 'ランダム'.tr(lang),
              onTap: () => onSelect(Layer4Mode.random),
            ),
          ],
        ),
      ),
    );
  }
}
