import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/app_languages.dart';
import '../../localization/app_strings.dart';
import '../../main.dart'
    show appSettings, cloudSync, jsstCalibrationPreferences;
import '../../models/long_article_word_selection_mode.dart';
import '../../models/vocab_answer_mode.dart';
import '../../services/app_logger.dart';
import '../../services/app_preferences.dart';
import '../../services/app_reset.dart';
import '../../services/cloud_sync/cloud_sync_service.dart';
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
import '../../utils/history_timestamp.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../theme/surface_theme.dart';
import '../../widgets/gradus_expand_card.dart';
import '../../widgets/settings_section.dart';
import 'alarm_sound_picker_screen.dart';
import 'question_prompt_tab_settings_screen.dart';
import 'speech_recognition_debug_log_view.dart';

/// アプリ設定画面。言語→読み上げ→タイマー音→データ（採点結果リセット/初期化）
/// →スタートアップ画面→プライバシー→（開発者向け）の並び。
class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({
    super.key,
    required this.settings,
    required this.speechReader,
    this.startExpanded = false,
  });

  final TtsSettingsService settings;
  final TopicSpeechReader speechReader;

  /// すべてのグループを開いた状態で始める。
  final bool startExpanded;

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

  /// 開いているグループ（見出しの翻訳キー）。
  final Set<String> _openGroups = {};

  Widget _group(
    String titleKey,
    IconData icon,
    Color accent,
    List<Widget> children,
  ) {
    final open = widget.startExpanded || _openGroups.contains(titleKey);
    return Padding(
      key: ValueKey('settings-group-$titleKey'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GradusExpandCard(
        title: titleKey.tr(appSettings.language),
        icon: icon,
        accent: accent,
        open: open,
        onToggle: () => setState(() {
          if (!_openGroups.remove(titleKey)) _openGroups.add(titleKey);
        }),
        child: Theme(
          data: SurfaceTheme.card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...children, const SizedBox(height: 12)],
          ),
        ),
      ),
    );
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

              const SizedBox(height: 20),
              _group('読み上げとタイマー', Icons.volume_up, Colors.orange, [
                Column(
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
                Column(
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
              ]),
              _group('問題文と語彙', Icons.label_outline, Colors.blue, [
                Column(
                  children: [
                    SettingsNavigationRow(
                      label: '問題文タブの管理'.tr(lang),
                      onTap: () =>
                          QuestionPromptTabSettingsScreen.push(context),
                    ),
                  ],
                ),

                const SettingsItemDivider(),
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
              ]),
              _group('案内とヒント', Icons.touch_app_outlined, Colors.teal, [
                Column(
                  children: [
                    SettingsSwitchRow(
                      label: 'スタートアップ画面'.tr(lang),
                      subtitle: 'スタートアップ画面_説明'.tr(lang),
                      value: appSettings.showStartupScreen,
                      onChanged: (value) =>
                          appSettings.showStartupScreen = value,
                    ),
                    const SettingsItemDivider(),
                    SettingsSwitchRow(
                      label: '使い方画面'.tr(lang),
                      subtitle: '使い方画面_説明'.tr(lang),
                      value: appSettings.showUsageScreen,
                      enabled: appSettings.showStartupScreen,
                      onChanged: (value) => appSettings.showUsageScreen = value,
                    ),
                  ],
                ),
                Column(
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
              ]),
              _group('データ', Icons.import_export, Colors.indigo, [
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
                // iCloud同期（iPhoneのみ。Androidでは出さない）。
                if (cloudSync case final sync?) ...[
                  const SettingsItemDivider(),
                  _CloudSyncSection(sync: sync),
                ],
              ]),
              if (showDeveloperTools)
                _group('開発者向け', Icons.code_rounded, Colors.grey, [
                  SettingsValueRow(
                    label: '補正係数'.tr(lang),
                    value: _calibrationBiasValue(lang),
                  ),
                  const SettingsItemDivider(),
                  SettingsNavigationRow(
                    label: '音声認識ログ'.tr(lang),
                    onTap: () => SpeechRecognitionDebugLogView.push(context),
                  ),
                  SettingsNoteText('音声認識ログ_設定説明'.tr(lang), onCard: true),
                ]),

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

/// iCloud同期（osmNichinichiの設定と同じ要素: オン／オフ・未サインインの注意・
/// 最終同期・今すぐ同期・エラー）。
class _CloudSyncSection extends StatelessWidget {
  const _CloudSyncSection({required this.sync});

  final CloudSyncService sync;

  /// 「今すぐ同期」。終わったら結果をスナックバーで知らせる
  /// （送るものが無くても反応が分かるように）。
  Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await sync.manualSync();
    final lang = appSettings.language;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text((ok ? 'iCloud同期_完了' : 'iCloud同期_失敗_短').tr(lang)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final lang = appSettings.language;
        final enabled = sync.isEnabled;
        final unavailable =
            sync.status == CloudSyncStatus.unavailable ||
            sync.icloudAvailable == false;
        final last = sync.lastSyncDate;
        final errorText = switch (sync.error) {
          CloudSyncError.tooLarge => 'iCloud同期_容量超過'.trFmt(lang, [
            ((sync.errorBytes ?? 0) / 1000000).toStringAsFixed(1),
          ]),
          CloudSyncError.failed => 'iCloud同期_失敗'.tr(lang),
          null => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                SettingsSwitchRow(
                  key: const ValueKey('settings-cloud-sync'),
                  label: 'iCloudで同期する'.tr(lang),
                  value: enabled,
                  onChanged: (value) => sync.setEnabled(value),
                ),
                if (enabled && !unavailable) ...[
                  const SettingsItemDivider(),
                  SettingsValueRow(
                    label: last == null
                        ? 'iCloud同期_未同期'.tr(lang)
                        : 'iCloud同期_最終同期'.tr(lang),
                    value: last == null
                        ? ''
                        : formatHistoryDetailTimestamp(
                            last,
                            languageCode: lang,
                          ),
                  ),
                  const SettingsItemDivider(),
                  SettingsValueRow(
                    key: const ValueKey('settings-cloud-sync-now'),
                    label: sync.isWorking
                        ? 'iCloud同期_同期中'.tr(lang)
                        : 'iCloud同期_今すぐ同期'.tr(lang),
                    value: '',
                    enabled: !sync.isWorking,
                    onTap: () => _syncNow(context),
                  ),
                ],
              ],
            ),
            if (enabled && unavailable)
              _CloudSyncWarning('iCloud同期_未サインイン'.tr(lang)),
            if (enabled && errorText != null) _CloudSyncWarning(errorText),
            SettingsNoteText('iCloud同期_説明'.tr(lang), onCard: true),
          ],
        );
      },
    );
  }
}

class _CloudSyncWarning extends StatelessWidget {
  const _CloudSyncWarning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}
