import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/thinking_matrix_layer.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mode_list_tile.dart';
import 'layer2_question_prompt_detail_screen.dart';
import 'layer2_question_prompt_screen.dart';
import 'layer2_random_screen.dart';
import 'thinking_matrix_screen.dart';

enum Layer2Mode { selectFromList, random, thinkingMatrix }

/// レイヤーⅡの入口（Step 3・Step 2で4択化）。「問題文一覧から選ぶ（問題文
/// 一覧→要約）」／「ランダム」（[Layer2RandomScreen]：サイコロで問題文を1件
/// 引く）／「25マスで考える」（[ThinkingMatrixScreen]：テーマ×視点の
/// 盤面。[ThinkingMatrixLayer.layer2]として開く）／「話題を増やす」
/// （画面には遷移せず、タップで直接Google検索を外部ブラウザで開く）の4択を
/// 出す。[Layer1EntryScreen]・[Layer3EntryScreen]と同じモード保持の考え方を
/// 踏襲するが、「話題を増やす」だけは[_mode]を持たない一回きりの外部遷移。
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
  final _randomKey = GlobalKey<Layer2RandomScreenState>();
  final _questionPromptKey = GlobalKey<Layer2QuestionPromptScreenState>();
  final _thinkingMatrixKey = GlobalKey<ThinkingMatrixScreenState>();

  Layer2Mode? get mode => _mode;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず、4択画面が
    // 古い言語のまま表示され続ける（モードを選んでから離れて戻ると、その
    // 遷移の再描画で偶然反映されてしまい気づきにくい）。appSettingsの変更を
    // 直接購読し、その場で再描画する（[Layer1EntryScreenState]と同じ理由）。
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  void _selectMode(Layer2Mode mode) {
    setState(() => _mode = mode);
  }

  /// 「話題を増やす」タップ用。画面遷移はせず、外部ブラウザでGoogle検索を
  /// 直接開く（旧「話題を増やす」画面のカテゴリ選択・サイコロ抽選・
  /// ＋取り込みは廃止）。
  Future<void> _openTopicSearch() async {
    final url = Uri.https('www.google.com', '/search', {
      'q': '日本語 スピーキング お題 一覧',
    });
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// 詳細画面の常設[AppHeader]「Ⅱ」タップから呼ぶ
  /// （[MainShellState._headerSelectLayer]参照）。現在のモードに関わらず、
  /// 必ず問題文一覧へ切り替える（ヘッダー経由では「今Ⅱが何のモードだったか」
  /// を選び直させず、常に一覧を見せるのが分かりやすいため）。
  void selectListMode() => _selectMode(Layer2Mode.selectFromList);

  /// 選択済みのモードを解除し、4択画面へ戻す
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
      null => _Layer2ModeSelect(
        onSelect: _selectMode,
        onOpenTopicSearch: _openTopicSearch,
      ),
      Layer2Mode.random => Layer2RandomScreen(key: _randomKey),
      Layer2Mode.thinkingMatrix => ThinkingMatrixScreen(
        key: _thinkingMatrixKey,
        layer: ThinkingMatrixLayer.layer2,
      ),
      Layer2Mode.selectFromList => Layer2QuestionPromptScreen(
        key: _questionPromptKey,
        onOpenPromptDetail: widget.onOpenPromptDetail,
        onSelectLayer: widget.onSelectLayer,
        onGoToStart: widget.onGoToStart,
      ),
    };
  }
}

/// レイヤーⅡの4択画面。[Layer1EntryScreen]・[Layer3EntryScreen]の選択画面と
/// 同じ、シーンの青地にアイコン＋ラベルの行を縦に並べるトーン。
class _Layer2ModeSelect extends StatelessWidget {
  const _Layer2ModeSelect({
    required this.onSelect,
    required this.onOpenTopicSearch,
  });

  final ValueChanged<Layer2Mode> onSelect;

  /// 「話題を増やす」専用。他の3つと違い[Layer2Mode]を経由せず、直接
  /// 外部ブラウザを開く。
  final VoidCallback onOpenTopicSearch;

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
              icon: Icons.grid_view_rounded,
              label: '25マスで考える'.tr(lang),
              onTap: () => onSelect(Layer2Mode.thinkingMatrix),
            ),
            ModeListTile(
              icon: Icons.public_rounded,
              label: '話題を増やす'.tr(lang),
              onTap: onOpenTopicSearch,
            ),
          ],
        ),
      ),
    );
  }
}
