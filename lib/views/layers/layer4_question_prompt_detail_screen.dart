import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../services/question_prompt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import 'layer4_screen.dart';

/// レイヤーⅣ「問題文一覧から選ぶ」の詳細画面（Step 5）。
///
/// レイヤーⅠ〜Ⅲの詳細画面と異なり専用UIは持たず、既存の録音・タイマー・
/// JSST採点・Chrome AI評価エンジンをそのまま持つ[Layer4Screen]を
/// [Layer4Screen.fixedPrompt]付きで包むだけ（共通ルール1・6：採点フローの
/// 二重実装を避け、枠位置もレイヤーⅣ「ランダム」と完全に同じにする）。
///
/// 一覧から開いたときの表示順（[promptIds]）を保持し、「分野」枠に置いた
/// ▲▼ボタン（[QuestionPromptNavRow]、[Layer4Screen]に組み込む）で前後の
/// 問題文へ画面を閉じずに移動できる（▲＝前、▼＝次）。[Layer4Screen]は
/// 録音・タイマーの実機依存な状態を多く持つため、[Layer1QuestionPromptDetailScreen]
/// のように内容ウィジェットを[ValueKey]で破棄・再生成するのではなく、
/// 同じ[Layer4Screen]インスタンス（[GlobalKey]で安定させる）に[fixedPrompt]
/// だけ差し替えて渡し、[Layer4ScreenState.didUpdateWidget]に明示的なリセット
/// を任せる。[Layer4ScreenState.isBusy]（読み上げ・録音・AI貼り付け待ち中）の
/// 間は、進行中の状態を失わせないよう▲▼ボタンでの移動を案内メッセージ付きで
/// 拒否する（[_confirmCanNavigate]）。
class Layer4QuestionPromptDetailScreen extends StatefulWidget {
  const Layer4QuestionPromptDetailScreen({
    super.key,
    required this.promptIds,
    required this.initialIndex,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  final List<String> promptIds;
  final int initialIndex;

  /// 「V」タップ時に呼ぶ（[MainShellState.openPromptDetailInLayer]への参照）。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 画面上端の常設[AppHeader]「Ⅰ」〜「Ⅴ」タップ時に呼ぶ
  /// （[MainShellState.selectLayer]相当への参照）。
  final ValueChanged<int>? onSelectLayer;

  /// 画面上端の常設[AppHeader]のいずれかのボタン長押し時に呼ぶ
  /// （スタート画面へジャンプする導線。この画面自身を閉じてから呼ぶ）。
  final VoidCallback? onGoToStart;

  static Future<void> push(
    BuildContext context, {
    required List<String> promptIds,
    required int initialIndex,
    void Function(int layerIndex, String promptId)? onOpenPromptDetail,
    ValueChanged<int>? onSelectLayer,
    VoidCallback? onGoToStart,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Layer4QuestionPromptDetailScreen(
          promptIds: promptIds,
          initialIndex: initialIndex,
          onOpenPromptDetail: onOpenPromptDetail,
          onSelectLayer: onSelectLayer,
          onGoToStart: onGoToStart,
        ),
      ),
    );
  }

  @override
  State<Layer4QuestionPromptDetailScreen> createState() =>
      _Layer4QuestionPromptDetailScreenState();
}

class _Layer4QuestionPromptDetailScreenState
    extends State<Layer4QuestionPromptDetailScreen> {
  final _service = QuestionPromptService();
  final _layer4Key = GlobalKey<Layer4ScreenState>();

  late int _index = widget.initialIndex;
  QuestionPrompt? _prompt;

  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < widget.promptIds.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prompt = await _service.loadById(widget.promptIds[_index]);
    if (!mounted) return;
    setState(() => _prompt = prompt);
  }

  /// ▲▼ボタンをタップした「その瞬間」に最新の[Layer4ScreenState.isBusy]を
  /// 読んで判定する（録音中などに内側だけが再構築されて変わりうるため、
  /// ボタンの`enabled`ではなくタップ時の判定に寄せている）。
  bool _confirmCanNavigate() {
    if (_layer4Key.currentState?.isBusy ?? false) {
      final lang = appSettings.language;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('録音中は移動できません'.tr(lang))));
      return false;
    }
    return true;
  }

  void _goPrevious() {
    if (!_canGoPrevious || !_confirmCanNavigate()) return;
    setState(() {
      _index -= 1;
      _prompt = null;
    });
    unawaited(_load());
  }

  void _goNext() {
    if (!_canGoNext || !_confirmCanNavigate()) return;
    setState(() {
      _index += 1;
      _prompt = null;
    });
    unawaited(_load());
  }

  void _handleHeaderSelect(int index) {
    Navigator.of(context).pop();
    widget.onSelectLayer?.call(index);
  }

  void _handleHeaderLongPress() {
    Navigator.of(context).pop();
    widget.onGoToStart?.call();
  }

  void _goToLayer5() {
    final prompt = _prompt;
    if (prompt == null) return;
    Navigator.of(context).pop();
    widget.onOpenPromptDetail?.call(4, prompt.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final prompt = _prompt;
    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        appBar: AppHeader(
          currentIndex: 3,
          onSelect: _handleHeaderSelect,
          onLongPress: _handleHeaderLongPress,
        ),
        body: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : Layer4Screen(
                key: _layer4Key,
                fixedPrompt: prompt,
                onGoToLayer5: _goToLayer5,
                canGoPrevious: _canGoPrevious,
                canGoNext: _canGoNext,
                onGoPrevious: _goPrevious,
                onGoNext: _goNext,
              ),
      ),
    );
  }
}
