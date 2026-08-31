import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/drawn_topic.dart';
import '../../models/question_prompt.dart';
import '../../models/topic_category.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/layer2_sample_answer_chrome_ai.dart';
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_label_row.dart';
import '../topics/topic_add_flow.dart';

/// レイヤーⅡ「ランダム」モード（Step 3拡張）。旧「話題を増やす」画面
/// （廃止済み）と同じ「サイコロで即座に引く」見た目・操作感を踏襲しつつ、
/// 抽選元を[TopicService]の題材バンクではなく[QuestionPromptService]の問題文
/// （＝「問題文一覧から選ぶ」と同じプール）にする。TTS読み上げ・タイマー・
/// 録音は一切行わず、サイコロを引いたら即座に問題文を表示するだけの
/// 軽量な画面（[PracticeLayerScreenState]は使わない）。
///
/// [QuestionPrompt.category]は[TopicCategory.random]を取らないため、カテゴリは
/// その他（[TopicCategory.general]）/シチュエーションの2つに絞る
/// （`question-prompt-tabs.md` Step 3、旧日常/ビジネスの3分類UIは廃止）。
/// 「その他」選択時は直下にタブ（[QuestionPromptTabRegistry]）の横スクロール
/// チップを出し、選択タブに含まれるgeneral問題だけを抽選対象にする
/// （未選択＝すべてのgeneralから抽選）。
class Layer2RandomScreen extends StatefulWidget {
  const Layer2RandomScreen({super.key});

  @override
  State<Layer2RandomScreen> createState() => Layer2RandomScreenState();
}

class Layer2RandomScreenState extends State<Layer2RandomScreen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin<Layer2RandomScreen>,
        ChromeAiSubmitMixin<Layer2RandomScreen>,
        Layer2SampleAnswerMixin<Layer2RandomScreen> {
  static const _availableCategories = [
    TopicCategory.general,
    TopicCategory.situational,
  ];

  final _service = QuestionPromptService();
  final _tabRegistry = QuestionPromptTabRegistry();
  final _idRandom = Random();

  TopicCategory _selectedCategory = TopicCategory.general;
  List<String> _tabKeys = const [];

  /// 選択中のタブ（null＝「すべて」）。[_selectedCategory]が
  /// [TopicCategory.general]のときだけ抽選に反映する。
  String? _selectedTag;
  QuestionPrompt? _drawnPrompt;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTabKeys());
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    stopKeepAliveIfOwned();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  QuestionPrompt? get sampleAnswerPrompt => _drawnPrompt;

  @override
  Future<void> saveSampleAnswer(String text) async {
    final prompt = _drawnPrompt;
    if (prompt == null) return;
    final updated = prompt.copyWith(sampleAnswer: text);
    await _service.update(updated);
    if (!mounted) return;
    setState(() => _drawnPrompt = updated);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  void _onSettingsChanged() => setState(() {});

  Future<void> _loadTabKeys() async {
    final tabKeys = await _tabRegistry.allTabKeys();
    if (!mounted) return;
    setState(() => _tabKeys = tabKeys);
  }

  Future<void> _drawPrompt() async {
    // 前の問題文の解答例の貼り付け待ち中に再抽選すると、表示が新しい問題文に
    // 差し替わったあとも貼り付け待ち状態だけ前の問題文のまま残ってしまい、
    // 新しい問題文で解答例アイコンをタップしたときに送信ではなく貼り付けが
    // 走ってしまう（_resetPrompt・カテゴリ変更と同じ理由）。
    if (chromeAiAwaitingPaste) clearChromeAiPendingState();
    setState(() => _drawing = true);
    final all = await _service.loadAll();
    final prompts = _service.filter(
      all,
      category: _selectedCategory,
      tag: _selectedCategory == TopicCategory.general ? _selectedTag : null,
    );
    if (!mounted) return;
    if (prompts.isEmpty) {
      setState(() => _drawing = false);
      return;
    }
    final prompt = prompts[_idRandom.nextInt(prompts.length)];
    setState(() {
      _drawnPrompt = prompt;
      _drawing = false;
    });
  }

  void _resetPrompt() {
    if (_drawnPrompt == null) return;
    // 解答例の貼り付け待ち中にリセットすると、表示中の問題文が消えたあとも
    // 貼り付け待ち状態だけ残ってしまい、次に別の問題文で解答例アイコンを
    // タップしたときに送信ではなく貼り付けが走ってしまう
    // （Step 7レビューで発見。レイヤーⅠ語彙テストの_resetAttemptと同じ理由で
    // ここでも解除する）。
    if (chromeAiAwaitingPaste) clearChromeAiPendingState();
    setState(() => _drawnPrompt = null);
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: _selectedCategory);

  /// 「＋」長押し：カテゴリ選択・サイコロ・イメージの3ステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_カテゴリ'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_イメージ'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_解答例'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_ノート'.tr(lang), indent: true),
      ],
    );
  }

  DrawnTopic? get _displayedTopic {
    final prompt = _drawnPrompt;
    if (prompt == null) return null;
    return DrawnTopic(
      category: prompt.category,
      text: prompt.body,
      subtext: prompt.situationCondition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiceActionRow(
                showAdd: true,
                addIcon: Icons.add_rounded,
                addTooltip: 'お題の取り込み',
                onAddTap: _showAddChoice,
                onAddLongPress: _showUsageHelp,
                addHintTapText: 'お題の取り込み',
                addHintLongPressText: '操作方法',
              ),
              const SizedBox(height: 4),
              CategorySelectField(
                selected: _selectedCategory,
                availableCategories: _availableCategories,
                onChanged: (category) {
                  // カテゴリ変更でも表示中の問題文が消えるため、_resetPromptと
                  // 同じ理由で解答例の貼り付け待ち状態を解除する。
                  if (chromeAiAwaitingPaste) clearChromeAiPendingState();
                  setState(() {
                    _selectedCategory = category;
                    _selectedTag = null;
                    _drawnPrompt = null;
                  });
                },
              ),
              if (_selectedCategory == TopicCategory.general) ...[
                const SizedBox(height: 8),
                _TagChipsScroller(
                  tabKeys: _tabKeys,
                  selected: _selectedTag,
                  onChanged: (tag) {
                    if (chromeAiAwaitingPaste) clearChromeAiPendingState();
                    setState(() {
                      _selectedTag = tag;
                      _drawnPrompt = null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 4),
              // シチュエーションの問題文は文章が長くなることがあるため、問題文
              // エリアはスクロール可能な領域に閉じ込める。ボタン列は下に固定
              // サイズで積み上げ、余った縦幅は全て問題文エリアに渡す。
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceTopicCard(topic: _displayedTopic),
                      const SizedBox(height: 8),
                      Text(
                        'どんな回答をするか想像して'.tr(lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _drawing ? null : _drawPrompt,
                  child: Container(
                    // 横長の長方形にする：高さはそのまま、幅だけ2倍にする。
                    width: 196,
                    height: 98,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: _drawing
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: palette.onAccent,
                            ),
                          )
                        : Icon(
                            Icons.casino,
                            // 余白ゼロ：アイコンをボタンの高さいっぱいまで大きくする。
                            size: 98,
                            color: palette.onAccent,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 「結論」「例示」はこのモードでは使わないため、枠だけ他レイヤーと
              // 揃えて確保し隠す（45/60/15+60・結果一覧に相当するものはこの
              // 画面にはない）。「理由」枠は抽選後だけ解答例ボタンに転用する
              // （未抽選時は一覧詳細と違って問題文自体が無いため隠したまま）。
              _drawnPrompt == null
                  ? const PrepLabelRow()
                  : PrepLabelRow(
                      showReason: true,
                      // 貼り付け待ち中はアイコン・色を変え、GenkiTransportRowの
                      // 送信/貼り付け切り替えと同じ見た目で「いま貼り付け待ち」
                      // だと一目で分かるようにする（実機報告の早すぎるタップ対策）。
                      reasonIcon: chromeAiAwaitingPaste
                          ? Icons.content_paste_go_rounded
                          : Icons.menu_book_rounded,
                      reasonTooltip: chromeAiAwaitingPaste ? '貼り付け' : '解答例',
                      reasonShowBorder: false,
                      reasonHorizontalPadding: 0,
                      reasonActive:
                          chromeAiAwaitingPaste ||
                          _drawnPrompt!.sampleAnswer.isNotEmpty,
                      reasonActiveForeground: chromeAiAwaitingPaste
                          ? kPasteReadyColor
                          : null,
                      onReasonTap: onSampleAnswerTap,
                      onReasonLongPress: onSampleAnswerLongPress,
                      reasonHintTapText: chromeAiAwaitingPaste
                          ? '貼り付け'
                          : (_drawnPrompt!.sampleAnswer.isEmpty
                                ? 'レイヤーⅡ_解答例_取得'
                                : '解答例'),
                      reasonHintLongPressText:
                          !chromeAiAwaitingPaste &&
                              _drawnPrompt!.sampleAnswer.isNotEmpty
                          ? 'レイヤーⅡ_解答例_再取得'
                          : null,
                    ),
              const SizedBox(height: 8),
              GenkiTransportRow(
                showReset: true,
                onReset: _resetPrompt,
                languageCode: lang,
                enableActionHints: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// タブ選択の横スクロールチップ行（「すべて」＋[tabKeys]、単一選択）。
/// [Layer2RandomScreen]の「その他」選択時のみ表示する。
class _TagChipsScroller extends StatelessWidget {
  const _TagChipsScroller({
    required this.tabKeys,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tabKeys;

  /// null＝「すべて」。
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return SizedBox(
      height: 34,
      // ListView.builderと違い全チップを常時ビルドする（件数が少なく、
      // widget testがスクロール位置に関わらずfind.textで見つけられるため）。
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TagChip(
              label: 'すべて'.tr(lang),
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final tabKey in tabKeys)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _TagChip(
                  label: tabKey.tr(lang),
                  selected: selected == tabKey,
                  onTap: () => onChanged(tabKey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final fill = selected ? palette.accentColor : Colors.transparent;
    final foreground = selected ? palette.onAccent : palette.textOnScenePrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.accentColor : palette.cardBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, color: foreground)),
      ),
    );
  }
}
