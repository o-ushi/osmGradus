import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/podcast_audio_handler.dart';
import 'notifiers/app_settings.dart';
import 'services/app_logger.dart';
import 'services/app_services.dart';
import 'services/app_preferences.dart';
import 'services/jsst_calibration_preferences.dart';
import 'services/podcast_library_service.dart';
import 'services/topic_speech_reader.dart';
import 'services/tts_settings_service.dart';
import 'theme/app_theme.dart';
import 'views/app_root_shell.dart';

late final PodcastAudioHandler audioHandler;
late final TtsSettingsService ttsSettings;
late final TopicSpeechReader topicSpeechReader;
late final JsstCalibrationPreferences jsstCalibrationPreferences;
late final AppPreferences appPreferences;
late final AppSettings appSettings;

/// レイアウトをiPhone向けの縦画面に統一する。iOS版はiPhone専用ターゲットのため、
/// iPadではOS標準のiPhone互換表示（縦向き・拡大）になる。
Future<void> _lockPortraitOrientation() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _lockPortraitOrientation();
      await AppLogger.instance.loadDeveloperMode();

      appPreferences = await AppPreferences.load();
      appSettings = AppSettings(appPreferences);
      AppServices.appPreferences = appPreferences;
      AppServices.appSettings = appSettings;

      ttsSettings = TtsSettingsService();
      await ttsSettings.load();
      AppServices.ttsSettings = ttsSettings;
      topicSpeechReader = TopicSpeechReader(ttsSettings);
      AppServices.topicSpeechReader = topicSpeechReader;

      jsstCalibrationPreferences = JsstCalibrationPreferences();
      await jsstCalibrationPreferences.load();
      AppServices.jsstCalibrationPreferences = jsstCalibrationPreferences;

      audioHandler = await AudioService.init(
        builder: () => PodcastAudioHandler(PodcastLibraryService()),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.osamushikubo.osm_gradus.audio',
          androidNotificationChannelName: 'osmGradus Podcast',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      AppServices.audioHandler = audioHandler;

      FlutterError.onError = (details) {
        AppLogger.instance.log(
          'FlutterError: ${details.exceptionAsString()}',
          level: LogLevel.error,
        );
        FlutterError.presentError(details);
      };

      runApp(const OsmGradusApp());
    },
    (error, stack) {
      AppLogger.instance.log('未捕捉の例外: $error', level: LogLevel.error);
    },
  );
}

class OsmGradusApp extends StatefulWidget {
  const OsmGradusApp({super.key});

  @override
  State<OsmGradusApp> createState() => _OsmGradusAppState();
}

class _OsmGradusAppState extends State<OsmGradusApp> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onGlobalSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onGlobalSettingsChanged);
    super.dispose();
  }

  void _onGlobalSettingsChanged() {
    setState(() {});
  }

  Locale get _locale => switch (appSettings.language) {
    'en' => const Locale('en'),
    'ja' => const Locale('ja'),
    _ => const Locale('vi'),
  };

  /// 端末の文字サイズ設定が等倍未満でも、アプリ内では等倍を下限とする。
  /// 拡大側はそのまま尊重する（アクセシビリティ設定を潰さないため）。
  Widget _applyMinimumTextScale(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    final media = MediaQuery.of(context);
    if (media.textScaler.scale(1.0) >= 1.0) return content;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        return MaterialApp(
          title: 'osmGradus',
          debugShowCheckedModeBanner: false,
          locale: _locale,
          theme: AppTheme.light(),
          builder: _applyMinimumTextScale,
          home: const AppRootShell(),
        );
      },
    );
  }
}
