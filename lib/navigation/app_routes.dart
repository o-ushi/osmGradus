import 'package:flutter/material.dart';

import '../services/pronunciation_check_storage.dart';
import '../services/scoring_result_storage.dart';
import '../services/vocabulary_check_storage.dart';
import '../views/dashboard/dashboard_screen.dart';
import '../views/export/transcript_screen.dart';
import '../views/help/help_screen.dart';
import '../views/layers/pronunciation_check_detail_screen.dart';
import '../views/layers/pronunciation_history_screen.dart';
import '../views/layers/scoring_history_screen.dart';
import '../views/layers/scoring_result_screen.dart';
import '../views/layers/vocabulary_check_detail_screen.dart';
import '../views/layers/vocabulary_check_history_screen.dart';
import '../views/settings/tts_settings_screen.dart';
import '../views/topics/question_prompt_overview_screen.dart';
import '../services/topic_speech_reader.dart';
import '../services/tts_settings_service.dart';

/// 画面遷移の共通エントリポイント。各画面の `push` をここへ集約する。
abstract final class AppRoutes {
  static Future<void> openDashboard(BuildContext context) =>
      DashboardScreen.push(context);

  /// 起動画面下端の「問題文一覧」から開く横断一覧（Step 9）。
  /// [onOpenLayer]は詳細のヘッダーⅠ〜ⅤタップでMainShellへ戻るときに使う。
  static Future<void> openQuestionPromptOverview(
    BuildContext context, {
    void Function(int index)? onOpenLayer,
  }) => QuestionPromptOverviewScreen.push(context, onOpenLayer: onOpenLayer);

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

  /// 結果ボタンの「タップ＝最新詳細」導線（Step 6）。[ScoringResultStorage.loadAll]
  /// の先頭（[JsonListStore]は新しい順）から、各`*HistoryScreen.onItemTap`と
  /// 同じ詳細画面を開く。保存済み結果が0件のときは何もしない（呼び出し元は
  /// 「例示」枠を`showExample: false`にして導線自体を出さない想定だが、
  /// 保険としてここでも空リストなら何もしない）。
  static Future<void> openLatestScoringResult(BuildContext context) async {
    final results = await ScoringResultStorage().loadAll();
    if (results.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScoringResultScreen(result: results.first),
      ),
    );
  }

  /// レイヤーⅤ（発音チェック・長文音読）の「タップ＝最新詳細」導線（Step 6）。
  static Future<void> openLatestPronunciationCheck(BuildContext context) async {
    final results = await PronunciationCheckStorage().loadAll();
    if (results.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PronunciationCheckDetailScreen(check: results.first),
      ),
    );
  }

  /// レイヤーⅠ単語テストの「タップ＝最新詳細」導線（Step 6）。
  static Future<void> openLatestVocabularyCheck(BuildContext context) async {
    final results = await VocabularyCheckStorage().loadAll();
    if (results.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VocabularyCheckDetailScreen(check: results.first),
      ),
    );
  }
}
