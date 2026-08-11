import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/app_languages.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, jsstCalibrationPreferences;
import '../../models/long_article_word_selection_mode.dart';
import '../../models/vocab_answer_mode.dart';
import '../../services/app_logger.dart';
import '../../services/app_preferences.dart';
import '../../services/app_reset.dart';
import '../../services/dashboard_advice_storage.dart';
import '../../services/jsst_calibration_service.dart';
import '../../services/native_tts_platform.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../services/question_prompt_service.dart';
import '../../services/scoring_result_storage.dart';
import '../../services/topic_speech_reader.dart';
import '../../services/tts_settings_service.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/settings_section.dart';
import 'alarm_sound_picker_screen.dart';
import 'privacy_data_screen.dart';
import 'speech_recognition_debug_log_view.dart';

/// アプリ設定画面。言語→読み上げ→タイマー音→データ（採点結果リセット/初期化）
/// →スタートアップ画面→プライバシー→（開発者向け）の並び。
class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({
    super.key,
    required this.settings,
    required this.speechReader,
  });

  final TtsSettingsService settings;
  final TopicSpeechReader speechReader;

  static Future<void> push(
    BuildContext context, {
    required TtsSettingsService settings,
    required TopicSpeechReader speechReader,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TtsSettingsScreen(settings: settings, speechReader: speechReader),
      ),
    );
  }

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
  static const _genderKeys = ['男性の声', '女性の声', 'ランダム'];
  static const _minRate = TtsSettingsService.minSpeechRate;
  static const _maxRate = TtsSettingsService.maxSpeechRate;

  final _scoringStorage = ScoringResultStorage();
  final _pronunciationStorage = PronunciationCheckStorage();
  final _vocabularyStorage = VocabularyCheckStorage();
  bool _hasSavedResults = false;

  /// osmWashabeの設定画面と同じ「隠し領域を7回タップで開発者モード切替」。
  int _devTapCount = 0;

  String get _lang => appSettings.language;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_rebuild);
    _loadSavedResultsFlag();
  }

  @override
  void dispose() {
    appSettings.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadSavedResultsFlag() async {
    final scoring = await _scoringStorage.loadAll();
    final pronunciation = await _pronunciationStorage.loadAll();
    final vocabulary = await _vocabularyStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _hasSavedResults =
          scoring.isNotEmpty ||
          pronunciation.isNotEmpty ||
          vocabulary.isNotEmpty;
    });
  }

  void _showGenderPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        actions: [
          for (final g in _genderKeys)
            CupertinoActionSheetAction(
              isDefaultAction: widget.settings.speechVoiceGender == g,
              onPressed: () {
                widget.settings.setSpeechVoiceGender(g);
                Navigator.pop(sheetCtx);
              },
              child: Text(g.tr(_lang)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: Text('キャンセル'.tr(_lang)),
        ),
      ),
    );
  }

  void _showButtonHintDisplaySecondsPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        actions: [
          for (final seconds in AppPreferences.buttonHintDisplaySecondsOptions)
            CupertinoActionSheetAction(
              isDefaultAction: appSettings.buttonHintDisplaySeconds == seconds,
              onPressed: () {
                appSettings.buttonHintDisplaySeconds = seconds;
                Navigator.pop(sheetCtx);
              },
              child: Text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['$seconds'])),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: Text('キャンセル'.tr(_lang)),
        ),
      ),
    );
  }

  String _displayRate(double rate) {
    final normalized = (rate - _minRate) / (_maxRate - _minRate);
    final display = normalized * 1.5 + 0.5;
    return '${display.toStringAsFixed(1)}×';
  }

  Future<bool> _confirmDestroy({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('キャンセル'.tr(_lang)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _resetSavedResults() async {
    final confirmed = await _confirmDestroy(
      title: '削除しますか？'.tr(_lang),
      message: '一度削除すると元に戻せません。'.tr(_lang),
      confirmLabel: '削除'.tr(_lang),
    );
    if (!confirmed || !mounted) return;
    await _scoringStorage.clearAll();
    await _pronunciationStorage.clearAll();
    await _vocabularyStorage.clearAll();
    await DashboardAdviceStorage().clear();
    await QuestionPromptService().clearAllScores();
    if (!mounted) return;
    setState(() => _hasSavedResults = false);
  }

  Future<void> _confirmReset() async {
    final confirmed = await _confirmDestroy(
      title: '本当に初期化しますか？'.tr(_lang),
      message: '初期化の説明'.tr(_lang),
      confirmLabel: '初期化'.tr(_lang),
    );
    if (!confirmed || !mounted) return;

    await AppReset.resetToFactoryDefaults();
    await widget.settings.load();
    await jsstCalibrationPreferences.load();
    appSettings.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('初期化しました'.tr(_lang))));
  }

  void _onDevAreaTap() {
    setState(() {
      _devTapCount++;
      if (_devTapCount < 7) return;
      _devTapCount = 0;
      final newValue = !AppLogger.instance.developerModeEnabled;
      unawaited(AppLogger.instance.setDeveloperModeEnabled(newValue));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? '開発者モードを有効にしました'.tr(_lang) : '開発者モードを無効にしました'.tr(_lang),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return OsmSubpageScaffold(
      title: Text('設定'.tr(_lang)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.settings,
          widget.speechReader,
          appSettings,
        ]),
        builder: (context, _) {
          final lang = _lang;
          final showDeveloperTools = AppLogger.instance.developerModeEnabled;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ─── 言語 ─────────────────────────────────────────
              SettingsSectionHeader('言語'.tr(lang)),
              SettingsSectionCard(
                children: [
                  for (var i = 0; i < appLanguages.length; i++) ...[
                    if (i > 0) const SettingsItemDivider(),
                    SettingsSelectableRow(
                      leading: Text(
                        appLanguages[i].$3,
                        style: const TextStyle(fontSize: 22),
                      ),
                      label: appLanguages[i].$2,
                      selected: appSettings.language == appLanguages[i].$1,
                      onTap: () => appSettings.language = appLanguages[i].$1,
                    ),
                  ],
                ],
              ),

              // ─── 読み上げ ─────────────────────────────────────
              SettingsSectionHeader('読み上げ'.tr(lang), icon: Icons.volume_up),
              SettingsSectionCard(
                children: [
                  SettingsValueRow(
                    label: '声質'.tr(lang),
                    value: widget.settings.speechVoiceGender.tr(lang),
                    onTap: _showGenderPicker,
                  ),
                  const SettingsItemDivider(),
                  _SpeechRateRow(
                    lang: lang,
                    rate: widget.settings.speechRate,
                    displayRate: _displayRate(widget.settings.speechRate),
                    onChanged: widget.settings.setSpeechRate,
                  ),
                  const SettingsItemDivider(),
                  SettingsValueRow(
                    label: '使用中の声'.tr(lang),
                    value: widget.speechReader.activeVoiceDescription,
                  ),
                ],
              ),
              if (!widget.speechReader.ttsAvailable)
                _TtsUnavailableNotice(
                  text: (Platform.isIOS ? '読み上げ_音声なし_iOS' : '読み上げ_音声なし').tr(
                    lang,
                  ),
                  onTap: () => NativeTtsPlatform.openSettings(),
                ),

              // ─── タイマー ─────────────────────────────────────
              SettingsSectionHeader(
                'タイマー音'.tr(lang),
                icon: Icons.notifications_none,
              ),
              SettingsSectionCard(
                children: [
                  SettingsValueRow(
                    label: 'タイマー音'.tr(lang),
                    value: widget.settings.alarmSoundTitle,
                    onTap: () => AlarmSoundPickerScreen.push(
                      context,
                      settings: widget.settings,
                    ),
                  ),
                ],
              ),

              // ─── データ ───────────────────────────────────────
              SettingsSectionHeader('データ'.tr(lang), icon: Icons.import_export),
              SettingsSectionCard(
                children: [
                  SettingsSwitchRow(
                    label: '標準のJLPT語彙を含める'.tr(lang),
                    subtitle: '標準のJLPT語彙を含める_説明'.tr(lang),
                    value: appSettings.includeDefaultVocabulary,
                    onChanged: (value) =>
                        appSettings.includeDefaultVocabulary = value,
                  ),
                  const SettingsItemDivider(),
                  SettingsSwitchRow(
                    label: '長文読解_単語選択方式'.tr(lang),
                    subtitle: '長文読解_単語選択方式_単語単位_説明'.tr(lang),
                    value:
                        appSettings.longArticleWordSelectionMode ==
                        LongArticleWordSelectionMode.chunk,
                    onChanged: (value) =>
                        appSettings.longArticleWordSelectionMode = value
                        ? LongArticleWordSelectionMode.chunk
                        : LongArticleWordSelectionMode.character,
                  ),
                  const SettingsItemDivider(),
                  SettingsSwitchRow(
                    label: '単語テスト_キーボード入力'.tr(lang),
                    subtitle: '単語テスト_キーボード入力_説明'.tr(lang),
                    value:
                        appSettings.vocabAnswerMode == VocabAnswerMode.keyboard,
                    onChanged: (value) => appSettings.vocabAnswerMode = value
                        ? VocabAnswerMode.keyboard
                        : VocabAnswerMode.voice,
                  ),
                  const SettingsItemDivider(),
                  SettingsDestructiveActionRow(
                    label: '採点結果をリセット'.tr(lang),
                    enabled: _hasSavedResults,
                    onTap: _resetSavedResults,
                  ),
                  const SettingsItemDivider(),
                  SettingsDestructiveActionRow(
                    label: 'すべてのデータを初期化'.tr(lang),
                    onTap: _confirmReset,
                  ),
                ],
              ),

              // ─── スタートアップ ───────────────────────────────
              SettingsSectionHeader('スタートアップ画面'.tr(lang)),
              SettingsSectionCard(
                children: [
                  SettingsSwitchRow(
                    label: 'スタートアップ画面'.tr(lang),
                    subtitle: 'スタートアップ画面_説明'.tr(lang),
                    value: appSettings.showStartupScreen,
                    onChanged: (value) => appSettings.showStartupScreen = value,
                  ),
                ],
              ),

              // ─── ボタンヒント（Step 7のダブルタップヒントの消え方）───
              SettingsSectionHeader(
                'ボタンヒント_設定セクション'.tr(lang),
                icon: Icons.touch_app_outlined,
              ),
              SettingsSectionCard(
                children: [
                  SettingsSwitchRow(
                    label: 'ボタンヒント_次のアクションまで表示'.tr(lang),
                    subtitle: 'ボタンヒント_次のアクションまで表示_説明'.tr(lang),
                    value: appSettings.buttonHintPersistUntilNextAction,
                    onChanged: (value) =>
                        appSettings.buttonHintPersistUntilNextAction = value,
                  ),
                  const SettingsItemDivider(),
                  SettingsValueRow(
                    label: 'ボタンヒント_表示期間'.tr(lang),
                    value: 'ボタンヒント_表示期間_秒'.trFmt(lang, [
                      '${appSettings.buttonHintDisplaySeconds}',
                    ]),
                    enabled: !appSettings.buttonHintPersistUntilNextAction,
                    onTap: _showButtonHintDisplaySecondsPicker,
                  ),
                ],
              ),

              // ─── プライバシー ─────────────────────────────────
              SettingsSectionHeader(
                'プライバシー'.tr(lang),
                icon: Icons.privacy_tip_outlined,
              ),
              SettingsSectionCard(
                children: [
                  SettingsNavigationRow(
                    label: 'プライバシーとデータ'.tr(lang),
                    onTap: () => PrivacyDataScreen.push(context),
                  ),
                ],
              ),

              // ─── 開発者向け ───────────────────────────────────
              if (showDeveloperTools) ...[
                SettingsSectionHeader('開発者向け'.tr(lang)),
                SettingsSectionCard(
                  children: [
                    SettingsValueRow(
                      label: '補正係数'.tr(lang),
                      value: _calibrationBiasValue(lang),
                    ),
                    const SettingsItemDivider(),
                    SettingsNavigationRow(
                      label: '音声認識ログ'.tr(lang),
                      onTap: () => SpeechRecognitionDebugLogView.push(context),
                    ),
                  ],
                ),
                SettingsNoteText('音声認識ログ_設定説明'.tr(lang)),
              ],

              GestureDetector(
                onTap: _onDevAreaTap,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(height: 40, width: double.infinity),
              ),
            ],
          );
        },
      ),
    );
  }

  String _calibrationBiasValue(String lang) {
    final bias = jsstCalibrationPreferences.bias;
    final count = jsstCalibrationPreferences.sampleCount;
    if (count == 0) return '—';
    final sign = bias >= 0 ? '+' : '';
    final tendency = JsstCalibrationService.biasLabel(bias).tr(lang);
    return '$sign${bias.toStringAsFixed(2)}（$tendency）';
  }
}

class _TtsUnavailableNotice extends StatelessWidget {
  const _TtsUnavailableNotice({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechRateRow extends StatelessWidget {
  const _SpeechRateRow({
    required this.lang,
    required this.rate,
    required this.displayRate,
    required this.onChanged,
  });

  final String lang;
  final double rate;
  final String displayRate;
  final ValueChanged<double> onChanged;

  static const _minRate = TtsSettingsService.minSpeechRate;
  static const _maxRate = TtsSettingsService.maxSpeechRate;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '読み上げ速度'.tr(lang),
                  style: TextStyle(
                    fontSize: 17,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
              Text(
                displayRate,
                style: TextStyle(
                  color: palette.textOnCardSecondary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          Slider(
            value: rate,
            min: _minRate,
            max: _maxRate,
            activeColor: palette.accentColor,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ゆっくり'.tr(lang),
                style: TextStyle(
                  color: palette.textOnCardSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                'はやい'.tr(lang),
                style: TextStyle(
                  color: palette.textOnCardSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
