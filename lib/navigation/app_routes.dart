import 'package:flutter/material.dart';

import '../views/dashboard/dashboard_screen.dart';
import '../views/export/transcript_screen.dart';
import '../views/help/help_screen.dart';
import '../views/layers/pronunciation_history_screen.dart';
import '../views/layers/scoring_history_screen.dart';
import '../views/layers/vocabulary_check_history_screen.dart';
import '../views/settings/tts_settings_screen.dart';
import '../services/topic_speech_reader.dart';
import '../services/tts_settings_service.dart';

/// 画面遷移の共通エントリポイント。各画面の `push` をここへ集約する。
abstract final class AppRoutes {
  static Future<void> openDashboard(BuildContext context) =>
      DashboardScreen.push(context);

  static Future<void> openTranscript(BuildContext context) =>
      TranscriptScreen.push(context);

  static Future<void> openHelp(BuildContext context) =>
      HelpScreen.push(context);

  static Future<void> openSettings(
    BuildContext context, {
    required TtsSettingsService settings,
    required TopicSpeechReader speechReader,
  }) => TtsSettingsScreen.push(
    context,
    settings: settings,
    speechReader: speechReader,
  );

  static Future<void> openScoringHistory(BuildContext context) =>
      ScoringHistoryScreen.push(context);

  static Future<void> openPronunciationHistory(BuildContext context) =>
      PronunciationHistoryScreen.push(context);

  static Future<void> openVocabularyHistory(BuildContext context) =>
      VocabularyCheckHistoryScreen.push(context);
}
