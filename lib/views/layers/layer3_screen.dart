import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../services/alarm_sound_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_stage_row.dart';
import '../../widgets/topic_speaker_timer_button.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../topics/topic_add_flow.dart';
import 'practice_layer_screen.dart';

/// レイヤーⅢ：言いたいことはあるが言葉にできない。
/// レイヤーⅡと同じ画面構成（カテゴリリスト・お題カード・サイコロボタン）を
/// ベースに、osmWashabeのタイマー・読み上げ（TTS）ロジックと、
/// osmGradus独自の「結論→理由→例示」点滅ガイドを組み合わせる。
/// サイコロボタンはosmGenkiのマイクボタンの見た目を借り、
/// サイコロ→スピーカー→カウントダウンの3状態を1つのボタンで表現する。
/// お題・TTS・タイマーの共通部分は[PracticeLayerScreenState]
/// （レイヤーⅣと共有）に集約されている。録音・採点は行わない。
class Layer3Screen extends StatefulWidget {
  const Layer3Screen({super.key});

  @override
  State<Layer3Screen> createState() => _Layer3ScreenState();
}

class _Layer3ScreenState extends PracticeLayerScreenState<Layer3Screen>
    with ResetButtonVisibilityMixin {
  String _resetStateKey() => [
    buttonPhase.name,
    selectedCategory.name,
    timerController.option.name,
    drawnTopic?.text ?? '',
  ].join('|');

  bool get _showResetButton => showResetButton(_resetStateKey());

  /// レイヤーⅢは母語で話す練習用で、録音結果も再生UIも使わない。
  @override
  bool get enablesRecording => false;

  @override
  bool get enablesPrepGuide => true;

  @override
  void onTimerFinished() {
    unawaited(playAlarmThenReturnToIdle());
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: selectedCategory);

  /// 「＋」長押し：タイマー〜PREP各段階までのステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅢ_使い方_タイマー'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_カテゴリ'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_音声回答'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_結論'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_理由'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_例示'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_使い方_ノート'.tr(lang), indent: true),
      ],
    );
  }

  /// リセットボタン：読み上げ・アラーム・カウントダウンを即座に中止し、
  /// 初期状態（サイコロボタン）に戻す。
  @override
  Future<void> resetAttempt() async {
    unawaited(topicSpeechReader.stop());
    unawaited(AlarmSoundService.stop());
    await recordingService.cancel();
    timerController.reset();
    prepStageController.reset();
    if (!mounted) return;
    setState(() {
      drawnTopic = null;
      buttonPhase = TopicSpeakerTimerPhase.idle;
      hideResetUntilNextChange(_resetStateKey());
    });
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
              ListenableBuilder(
                listenable: timerController,
                builder: (context, _) => DiceActionRow(
                  show45: true,
                  show60: true,
                  show15Plus60: true,
                  showAdd: true,
                  addIcon: Icons.add_rounded,
                  addTooltip: 'お題の取り込み',
                  selectedOption: timerController.option,
                  onPresetTap: onPresetTap,
                  onAddTap: _showAddChoice,
                  onAddLongPress: _showUsageHelp,
                  addHintTapText: 'お題の取り込み',
                  addHintLongPressText: '操作方法',
                ),
              ),
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: timerController,
                builder: (context, _) => CategorySelectField(
                  selected: selectedCategory,
                  availableCategories: availableCategories,
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceTopicCard(topic: drawnTopic),
                      const SizedBox(height: 8),
                      Text(
                        '母語で回答してOK'.tr(lang),
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
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    timerController,
                    topicSpeechReader,
                  ]),
                  builder: (context, _) => TopicSpeakerTimerButton(
                    phase: buttonPhase,
                    remainingSeconds: timerController.remainingSeconds,
                    isPaused: topicSpeechReader.isPaused,
                    onTap: onButtonTap,
                    size: 98,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrepStageRow(controller: prepStageController),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: timerController,
                builder: (context, _) => GenkiTransportRow(
                  showReset: _showResetButton,
                  languageCode: lang,
                  onReset: resetAttempt,
                  enableActionHints: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
