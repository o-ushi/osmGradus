import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/thinking_matrix_layer.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer3_question_prompt_detail_screen.dart';
import 'layer3_question_prompt_screen.dart';
import 'layer3_screen.dart';
import 'practice_layer_screen.dart';
import 'thinking_matrix_screen.dart';

enum Layer3Mode { selectFromList, random, thinkingMatrix }

/// レイヤーⅢの入口（Step 4・layer2-3-thinking-matrix.md Step 3で3択化）。
/// 「問題文一覧から選ぶ（問題文一覧→PREP記入）」／「ランダム」（既存の
/// [Layer3Screen]：サイコロ抽選・タイマー・PREPガイド）／「25マスで考える」
/// （[ThinkingMatrixScreen]：Ⅱと同じ盤面・同じ[ThinkingMatrixService]を
/// [ThinkingMatrixLayer.layer3]として開き、キーワードに加えPREPまで書き込める）
/// の3択を出す。[Layer2EntryScreen]と同じモード保持・スキップ遷移の
/// 考え方を踏襲する。
class Layer3EntryScreen extends StatefulWidget {
  const Layer3EntryScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// レイヤーⅡ・Ⅳ〜Ⅴの詳細画面のIII〜Vボタンから
  /// [MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer3EntryScreen> createState() => Layer3EntryScreenState();
}

class Layer3EntryScreenState extends State<Layer3EntryScreen> {
  Layer3Mode? _mode;
  final _randomKey = GlobalKey<PracticeLayerScreenState<Layer3Screen>>();
  final _questionPromptKey = GlobalKey<Layer3QuestionPromptScreenState>();
  final _thinkingMatrixKey = GlobalKey<ThinkingMatrixScreenState>();

  Layer3Mode? get mode => _mode;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず、3択画面が
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

  void _selectMode(Layer3Mode mode) {
    setState(() => _mode = mode);
  }

  /// 詳細画面の常設[AppHeader]「Ⅲ」タップから呼ぶ
  /// （[MainShellState._headerSelectLayer]参照）。[Layer2EntryScreenState.selectListMode]
  /// と同じく、常に問題文一覧へ切り替える。
  void selectListMode() => _selectMode(Layer3Mode.selectFromList);

  /// 選択済みのモードを解除し、3択画面へ戻す
  /// （ヘッダー「Ⅲ」再タップ・「始めから始める」長押しから呼ぶ）。
  void resetMode() {
    if (!mounted || _mode == null) return;
    setState(() => _mode = null);
  }

  /// [MainShellState._selectLayer]がレイヤーⅢから離れる直前に呼ぶ。
  /// 「ランダム」モード（既存[Layer3Screen]）が裏で読み上げ・カウントダウンを
  /// 動かし続けないよう止める（[Layer3ScreenState]が未マウントなら無視）。
  Future<void> resetAttempt() async {
    await _randomKey.currentState?.resetAttempt();
  }

  /// レイヤーⅡの「III」から呼ばれる。トップ・一覧をスキップし、指定した
  /// 問題文のⅢ詳細を直接開く。
  ///
  /// [_mode]を`selectFromList`に切り替えるだけでは、既に`selectFromList`に
  /// なっている場合[Layer3QuestionPromptScreen]が使い回され、
  /// [State.initState]は再実行されない。そのため、一覧が新規生成されたかに
  /// 関わらず、ここで確実に[Layer3QuestionPromptDetailScreen]を直接pushする
  /// （[Layer2EntryScreenState.openPromptDetail]と同じ設計）。
  void openPromptDetail(String promptId) {
    setState(() => _mode = Layer3Mode.selectFromList);
    unawaited(_pushPromptDetail(promptId));
  }

  Future<void> _pushPromptDetail(String promptId) async {
    await Layer3QuestionPromptDetailScreen.push(
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
      null => _Layer3ModeSelect(onSelect: _selectMode),
      Layer3Mode.random => Layer3Screen(key: _randomKey),
      Layer3Mode.thinkingMatrix => ThinkingMatrixScreen(
        key: _thinkingMatrixKey,
        layer: ThinkingMatrixLayer.layer3,
      ),
      Layer3Mode.selectFromList => Layer3QuestionPromptScreen(
        key: _questionPromptKey,
        onOpenPromptDetail: widget.onOpenPromptDetail,
        onSelectLayer: widget.onSelectLayer,
        onGoToStart: widget.onGoToStart,
      ),
    };
  }
}

/// レイヤーⅢの3択画面。[Layer2EntryScreen]の4択画面と同じ、シーンの青地に
/// アイコン＋ラベルの行を縦に並べるトーン。
class _Layer3ModeSelect extends StatelessWidget {
  const _Layer3ModeSelect({required this.onSelect});

  final ValueChanged<Layer3Mode> onSelect;

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
              onTap: () => onSelect(Layer3Mode.selectFromList),
            ),
            ModeListTile(
              icon: Icons.casino_rounded,
              label: 'ランダム'.tr(lang),
              onTap: () => onSelect(Layer3Mode.random),
            ),
            ModeListTile(
              icon: Icons.grid_view_rounded,
              label: '25マスで考える'.tr(lang),
              onTap: () => onSelect(Layer3Mode.thinkingMatrix),
            ),
          ],
        ),
      ),
    );
  }
}
