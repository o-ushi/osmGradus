import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../services/question_prompt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import 'layer5_screen.dart';

/// レイヤーⅤ「問題文一覧から選ぶ」の詳細画面（Step 6・Step 5で画面統一）。
///
/// レイヤーⅠ〜Ⅳの詳細画面と同じく専用UIは持たず、常設[AppHeader]と
/// [SwipeToCloseWrapper]で[Layer5Screen]（`gradedPrompt`モード。「ランダム」
/// と同じ複数問セッションUI、Step 5）を包むだけ（[Layer4QuestionPromptDetailScreen]
/// と同じ設計）。
///
/// 一覧から開いたときの表示順（[promptIds]）を保持し、「分野」枠に置いた
/// ▲▼ボタン（[QuestionPromptNavRow]、[Layer5Screen]に組み込む）で前後の
/// 問題文へ画面を閉じずに移動できる（▲＝前、▼＝次）。[Layer4QuestionPromptDetailScreen]
/// と同じく、[Layer5Screen]は[GlobalKey]で安定させて対象の問題文だけ差し替え、
/// [Layer5ScreenState.didUpdateWidget]にリセットを任せる。[Layer5ScreenState.isBusy]
/// （録音・文字起こし・AI貼り付け待ち中）の間は、進行中の状態を失わせないよう
/// ▲▼ボタンでの移動を案内メッセージ付きで拒否する。
class Layer5QuestionPromptDetailScreen extends StatefulWidget {
  const Layer5QuestionPromptDetailScreen({
    super.key,
    required this.promptIds,
    required this.initialIndex,
    this.onSelectLayer,
    this.onGoToStart,
    this.onGoToSummary,
  });

  final List<String> promptIds;
  final int initialIndex;

  /// 画面上端の常設[AppHeader]「Ⅰ」〜「Ⅴ」タップ時に呼ぶ
  /// （[MainShellState.selectLayer]相当への参照）。
  final ValueChanged<int>? onSelectLayer;

  /// 画面上端の常設[AppHeader]のいずれかのボタン長押し時に呼ぶ
  /// （スタート画面へジャンプする導線。この画面自身を閉じてから呼ぶ）。
  final VoidCallback? onGoToStart;

  /// AI発音評価が届いた後の「総評」タップで、この問題文のIDを渡して呼ぶ
  /// （[QuestionPromptSummaryScreen]への遷移）。
  final void Function(String promptId)? onGoToSummary;

  static Future<void> push(
    BuildContext context, {
    required List<String> promptIds,
    required int initialIndex,
    ValueChanged<int>? onSelectLayer,
    VoidCallback? onGoToStart,
    void Function(String promptId)? onGoToSummary,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Layer5QuestionPromptDetailScreen(
          promptIds: promptIds,
          initialIndex: initialIndex,
          onSelectLayer: onSelectLayer,
          onGoToStart: onGoToStart,
          onGoToSummary: onGoToSummary,
        ),
      ),
    );
  }

  @override
  State<Layer5QuestionPromptDetailScreen> createState() =>
      _Layer5QuestionPromptDetailScreenState();
}

class _Layer5QuestionPromptDetailScreenState
    extends State<Layer5QuestionPromptDetailScreen> {
  final _service = QuestionPromptService();
  final _recordingKey = GlobalKey<Layer5ScreenState>();

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

  /// ▲▼ボタンをタップした瞬間に最新の[isBusy]を読む
  /// （[Layer4QuestionPromptDetailScreen._confirmCanNavigate]と同じ理由）。
  bool _confirmCanNavigate() {
    if (_recordingKey.currentState?.isBusy ?? false) {
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

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final prompt = _prompt;
    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        appBar: AppHeader(
          currentIndex: 4,
          onSelect: _handleHeaderSelect,
          onLongPress: _handleHeaderLongPress,
        ),
        body: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : Layer5Screen(
                key: _recordingKey,
                gradedPrompt: prompt,
                onGoToSummary: widget.onGoToSummary,
                canGoPrevious: _canGoPrevious,
                canGoNext: _canGoNext,
                onGoPrevious: _goPrevious,
                onGoNext: _goNext,
              ),
      ),
    );
  }
}
