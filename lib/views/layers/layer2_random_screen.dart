import 'dart:math';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/drawn_topic.dart';
import '../../models/question_prompt.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_label_row.dart';
import '../topics/topic_add_flow.dart';

/// レイヤーⅡ「ランダム」モード（Step 3拡張）。[Layer2Screen]（「話題を増やす」）
/// と同じ「サイコロで即座に引く」見た目・操作感を踏襲しつつ、抽選元を
/// [TopicService]の題材バンクではなく[QuestionPromptService]の問題文
/// （＝「問題文一覧から選ぶ」と同じプール）にする。TTS読み上げ・タイマー・
/// 録音は一切行わず、サイコロを引いたら即座に問題文を表示するだけの
/// 軽量な画面（[PracticeLayerScreenState]は使わない）。
///
/// [QuestionPrompt.field]は[TopicCategory.random]を取らないため、分野は
/// 日常/ビジネス/シチュエーションの3つに絞る。
class Layer2RandomScreen extends StatefulWidget {
  const Layer2RandomScreen({super.key});

  @override
  State<Layer2RandomScreen> createState() => Layer2RandomScreenState();
}

class Layer2RandomScreenState extends State<Layer2RandomScreen> {
  static const _availableCategories = [
    TopicCategory.daily,
    TopicCategory.business,
    TopicCategory.situational,
  ];

  final _service = QuestionPromptService();
  final _idRandom = Random();

  TopicCategory _selectedCategory = TopicCategory.daily;
  QuestionPrompt? _drawnPrompt;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _drawPrompt() async {
    setState(() => _drawing = true);
    final prompts = await _service.loadByField(_selectedCategory);
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
    setState(() => _drawnPrompt = null);
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: _selectedCategory);

  /// 「＋」長押し：分野選択・サイコロ・イメージの3ステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_分野'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_イメージ'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_ランダム_使い方_ノート'.tr(lang), indent: true),
      ],
    );
  }

  DrawnTopic? get _displayedTopic {
    final prompt = _drawnPrompt;
    if (prompt == null) return null;
    return DrawnTopic(
      category: prompt.field,
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
                  setState(() {
                    _selectedCategory = category;
                    _drawnPrompt = null;
                  });
                },
              ),
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
              // このモードでは「結論」「理由」「例示」のいずれも使わないため、
              // 枠だけ他レイヤーと揃えて確保し隠す
              // （45/60/15+60・結果一覧に相当するものはこの画面にはない）。
              const PrepLabelRow(),
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
