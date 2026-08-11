import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer2_question_prompt_detail_screen.dart';
import 'layer2_question_prompt_screen.dart';
import 'layer2_random_screen.dart';
import 'layer2_screen.dart';

enum Layer2Mode { selectFromList, random, increaseTopics }

/// レイヤーⅡの入口（Step 3）。「問題文一覧から選ぶ（問題文一覧→要約）」／
/// 「ランダム」（[Layer2RandomScreen]：サイコロで問題文を1件引く）／
/// 「話題を増やす」（既存の[Layer2Screen]：サイコロ抽選・🌐検索・＋取り込み）
/// の3択を出す。[Layer1EntryScreen]・[Layer3EntryScreen]と同じモード保持の
/// 考え方を踏襲する。
class Layer2EntryScreen extends StatefulWidget {
  const Layer2EntryScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// レイヤーⅠ・Ⅲ〜Ⅴの詳細画面のII〜Vボタンから
  /// [MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer2EntryScreen> createState() => Layer2EntryScreenState();
}

class Layer2EntryScreenState extends State<Layer2EntryScreen> {
  Layer2Mode? _mode;
  final _increaseTopicsKey = GlobalKey<Layer2ScreenState>();
  final _randomKey = GlobalKey<Layer2RandomScreenState>();
  final _questionPromptKey = GlobalKey<Layer2QuestionPromptScreenState>();

  Layer2Mode? get mode => _mode;

  void _selectMode(Layer2Mode mode) {
    setState(() => _mode = mode);
  }

  /// 詳細画面の常設[AppHeader]「Ⅱ」タップから呼ぶ
  /// （[MainShellState._headerSelectLayer]参照）。現在のモードに関わらず、
  /// 必ず問題文一覧へ切り替える（ヘッダー経由では「今Ⅱが何のモードだったか」
  /// を選び直させず、常に一覧を見せるのが分かりやすいため）。
  void selectListMode() => _selectMode(Layer2Mode.selectFromList);

  /// 選択済みのモードを解除し、3択画面へ戻す
  /// （ヘッダー「Ⅱ」再タップ・「始めから始める」長押しから呼ぶ）。
  void resetMode() {
    if (!mounted || _mode == null) return;
    setState(() => _mode = null);
  }

  /// レイヤーⅠの「II」から呼ばれる。トップ・一覧をスキップし、指定した
  /// 問題文のⅡ詳細を直接開く。
  ///
  /// [_mode]を`selectFromList`に切り替えるだけでは、既に`selectFromList`に
  /// なっている場合（一度Ⅱへ来たあとⅠへ寄り道して再び「II」を押した場合）
  /// [Layer2QuestionPromptScreen]が使い回され、[State.initState]は
  /// 再実行されない。そのため、一覧が新規生成されたかどうかに関わらず、
  /// ここで確実に[Layer2QuestionPromptDetailScreen]を直接pushする。
  void openPromptDetail(String promptId) {
    setState(() => _mode = Layer2Mode.selectFromList);
    unawaited(_pushPromptDetail(promptId));
  }

  Future<void> _pushPromptDetail(String promptId) async {
    await Layer2QuestionPromptDetailScreen.push(
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
      null => _Layer2ModeSelect(onSelect: _selectMode),
      Layer2Mode.increaseTopics => Layer2Screen(key: _increaseTopicsKey),
      Layer2Mode.random => Layer2RandomScreen(key: _randomKey),
      Layer2Mode.selectFromList => Layer2QuestionPromptScreen(
        key: _questionPromptKey,
        onOpenPromptDetail: widget.onOpenPromptDetail,
        onSelectLayer: widget.onSelectLayer,
        onGoToStart: widget.onGoToStart,
      ),
    };
  }
}

/// レイヤーⅡの3択画面。[Layer1EntryScreen]・[Layer3EntryScreen]の選択画面と
/// 同じ、シーンの青地にアイコン＋ラベルの行を縦に並べるトーン。
class _Layer2ModeSelect extends StatelessWidget {
  const _Layer2ModeSelect({required this.onSelect});

  final ValueChanged<Layer2Mode> onSelect;

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
              onTap: () => onSelect(Layer2Mode.selectFromList),
            ),
            ModeListTile(
              icon: Icons.casino_rounded,
              label: 'ランダム'.tr(lang),
              onTap: () => onSelect(Layer2Mode.random),
            ),
            ModeListTile(
              icon: Icons.public_rounded,
              label: '話題を増やす'.tr(lang),
              onTap: () => onSelect(Layer2Mode.increaseTopics),
            ),
          ],
        ),
      ),
    );
  }
}
