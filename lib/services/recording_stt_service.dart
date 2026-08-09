import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/scoring_models.dart';
import 'screen_wake_service.dart';
import 'speech_recognition_debug_log_store.dart';
import 'vosk_model_manager.dart';

const _wakeReasonTranscribing = 'transcribing';

void _logDebug(String message) {
  unawaited(SpeechRecognitionDebugLogStore.instance.add(message));
}

/// 文字起こしの進捗（0.0〜1.0）とフェーズ文言の組。
typedef TranscribeProgress = ({double progress, String phase});

/// レイヤーⅣの発話フェーズ中、ユーザーの発話を録音・文字起こしする。
/// osmWashabeの`SpeechRecognitionService`の移植（TTS読み上げ連携・
/// バックグラウンドキープアライブ連携など、osmGradusに存在しない
/// 周辺機能は含めず、録音〜文字起こしのコア部分のみを移植する）。
///
/// iOS:     AVAudioRecorderで録音 → SFSpeechURLRecognitionRequestで変換
///          （ネイティブMethodChannel）。
/// Android: 無音録音 → SpeechRecognizer（ファイル入力）→
///          失敗時のみVoskオフライン文字起こしにフォールバック。
class RecordingSttService {
  static const _storedRecordingNames = [
    'layer4_recording.m4a',
    'layer4_recording.wav',
  ];

  static const _captureChannelName =
      'com.osamushikubo.osm_gradus/speech_capture';
  static const _progressChannelName =
      'com.osamushikubo.osm_gradus/speech_capture_progress';
  final MethodChannel _captureChannel = const MethodChannel(
    _captureChannelName,
  );
  final EventChannel _progressChannel = const EventChannel(
    _progressChannelName,
  );

  bool _recording = false;
  bool _isTranscribing = false;
  final List<TranscriptChunk> _chunks = [];

  String? _lastRecordingPath;
  DateTime? _sessionStartedAt;
  DateTime? _sessionEndedAt;

  double _transcribeProgress = 0;
  String _transcribePhase = phaseAnalyzing;
  final _progressController = StreamController<TranscribeProgress>.broadcast();

  static const _modelPrepProgressShare = 0.3;

  /// osmWashabeの`採点中_音声解析`/`採点中_モデル準備`/`採点中_モデル読み込み`に相当する
  /// 進捗フェーズ文言（Android Voskフォールバック時のみ意味を持つ）。
  static const phaseAnalyzing = '音声を解析しています…';
  static const phaseModelPreparing = '音声認識モデルを準備中…（初回のみ）';
  static const phaseModelLoading = '音声認識モデルを読み込んでいます…';

  bool get isRecording => _recording;
  bool get isTranscribing => _isTranscribing;
  String? get lastRecordingPath => _lastRecordingPath;

  /// 直近の文字起こし進捗（0.0〜1.0）。iOS・オンライン認識のみで完了した
  /// 場合は意味のある中間値を持たず、0→1に一気に進む。
  double get transcribeProgress => _transcribeProgress;

  /// 直近の進捗フェーズ文言。
  String get transcribePhase => _transcribePhase;

  /// 文字起こし進捗の変化を通知するストリーム（Android Voskフォールバック時、
  /// UIに進捗バー・フェーズ文言を表示するために使う）。
  Stream<TranscribeProgress> get transcribeProgressStream =>
      _progressController.stream;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  DateTime? get sessionEndedAt => _sessionEndedAt;

  /// [JsstScoringService.score]に渡すセッション時間枠を組み立てる。
  SpeechSessionContext sessionContext({required int allottedSeconds}) =>
      SpeechSessionContext(
        allottedSeconds: allottedSeconds,
        startedAt: _sessionStartedAt,
        endedAt: _sessionEndedAt,
      );

  Future<bool> hasRecordPermission() async {
    if (Platform.isIOS) return true; // iOS側はstartCapture内で許可を求める
    try {
      final granted = await _captureChannel
          .invokeMethod<bool>('hasRecordPermission')
          .timeout(const Duration(seconds: 3));
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestRecordPermission() async {
    if (Platform.isIOS) return true;
    try {
      final granted = await _captureChannel
          .invokeMethod<bool>('requestRecordPermission')
          .timeout(const Duration(seconds: 30)); // ユーザーの許可ダイアログ操作を待つため長め
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 発話フェーズ開始時に呼ぶ。録音を開始する。録音が開始できたらtrue。
  Future<bool> startRecording() async {
    _chunks.clear();
    _sessionStartedAt = null;
    _sessionEndedAt = null;

    _logDebug('録音開始を試行 (${Platform.operatingSystem})');
    final ok = Platform.isAndroid
        ? await _startAndroidRecording()
        : await _startIosRecording();
    _logDebug(ok ? '録音開始に成功' : '録音開始に失敗');
    return ok;
  }

  /// 発話フェーズ終了時に呼ぶ。録音停止→文字起こし→チャンクを返す。
  /// [locale]はSTTに渡すBCP-47ロケールタグ（例: 'ja-JP'、'vi-VN'、'en-US'）。
  /// レイヤーⅣ/Ⅴ（学習者が常に日本語で話す）は既定の'ja-JP'のまま使い、
  /// レイヤーⅠの単語テスト（学習者がベトナム語/英語/日本語で口頭回答する）
  /// だけ選択中の回答言語を明示的に渡す。
  /// [allowVoskFallback]がfalseのとき（レイヤーⅠ単語テスト）はAndroidでも
  /// SpeechRecognizerのみを使い、Voskオフライン文字起こしには落とさない。
  /// [skipOnlineRecognition]がtrueのとき（レイヤーⅣの45〜60秒発話）はAndroidで
  /// SpeechRecognizerを試さず、録音済みWAVをVoskで直接文字起こしする。
  Future<List<TranscriptChunk>> stopAndTranscribe({
    String locale = 'ja-JP',
    bool allowVoskFallback = true,
    bool skipOnlineRecognition = false,
  }) async {
    if (!_recording) return List.unmodifiable(_chunks);

    _logDebug(
      '録音停止・文字起こしを開始 (locale: $locale'
      '${skipOnlineRecognition ? ', Voskのみ' : ''})',
    );
    final chunks = Platform.isAndroid
        ? await _stopAndroidRecording(
            locale,
            allowVoskFallback: allowVoskFallback,
            skipOnlineRecognition: skipOnlineRecognition,
          )
        : await _stopIosRecording(locale);
    _logDebug('文字起こし完了: ${chunks.length}件のチャンク');
    return chunks;
  }

  /// 発話フェーズを録音・文字起こしせずに中断する（リセット時に使う）。
  /// タイムアウトを付けないと、プラットフォームチャンネルが応答しない場合に
  /// 永久に完了しないFutureになり、呼び出し元（リセットボタン）が
  /// フリーズしてしまう。
  Future<void> cancel() async {
    // 録音していない状態（キーボード入力モードでのリセットなど）でネイティブ
    // 側のstopCapture/cancelRecordingを呼ぶと、iOSではAVAudioSessionが
    // 無条件に非アクティブ化され、その副作用でソフトウェアキーボードだけが
    // 閉じてしまう（FocusNodeはフォーカス済みのままなので再表示されない）。
    // 録音中でなければネイティブ呼び出し自体をスキップする。
    if (_recording) {
      _logDebug('録音・文字起こしをキャンセル');
      try {
        if (Platform.isAndroid) {
          await _captureChannel
              .invokeMethod<void>('cancelRecording')
              .timeout(const Duration(seconds: 3));
        } else {
          await _captureChannel
              .invokeMethod<void>('stopCapture')
              .timeout(const Duration(seconds: 3));
        }
      } catch (e) {
        _logDebug('キャンセル処理でエラー: $e');
      }
    }
    _recording = false;
    _isTranscribing = false;
    unawaited(ScreenWakeService.instance.release(_wakeReasonTranscribing));
  }

  /// 直近の録音ファイルをディスクから削除し、[lastRecordingPath]をnullに戻す。
  /// リセットボタンなど、録音データを完全に破棄したいときに呼ぶ
  /// （[cancel]自体はファイルを消さないため、聞き直しボタンの「再生できる
  /// データがある」表示もこれを呼ばないと消えない）。
  Future<void> clearLastRecording() async {
    final path = _lastRecordingPath;
    _lastRecordingPath = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 「全データ初期化」用。サービスのインスタンスが破棄済みでも、固定名で
  /// Documentsに残り得る直近録音をすべて削除する。
  static Future<void> clearStoredRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final name in _storedRecordingNames) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // 初期化は、録音ファイルが存在しない／Documentsを取得できない場合でも
      // SharedPreferencesの削除を継続できるようbest-effortとする。
    }
  }

  void dispose() {
    // cancel()の.timeout()はDart Timerを生成する。dispose()はfire-and-forgetで
    // 結果を待たないため、そのTimerが破棄後も残り続けてしまう
    // （ウィジェットテストの「pending timer」検証にも引っかかる）。
    // 破棄時は結果を問わないので、タイムアウトなしの素の呼び出しで十分。
    // catchError()で非同期エラーだけ確実に握りつぶす（awaitはしない）。
    if (Platform.isAndroid) {
      unawaited(
        _captureChannel
            .invokeMethod<void>('cancelRecording')
            .catchError((_) {}),
      );
    } else {
      unawaited(
        _captureChannel.invokeMethod<void>('stopCapture').catchError((_) {}),
      );
    }
    _recording = false;
    _isTranscribing = false;
    unawaited(ScreenWakeService.instance.release(_wakeReasonTranscribing));
    _progressController.close();
  }

  // ── iOS ──────────────────────────────────────────────────────────────────

  Future<bool> _startIosRecording() async {
    final String outputPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      outputPath = '${dir.path}/layer4_recording.m4a';
    } catch (_) {
      return false;
    }

    try {
      final ok = await _captureChannel
          .invokeMethod<bool>('startCapture', {'outputPath': outputPath})
          .timeout(const Duration(seconds: 5));
      if (ok != true) return false;
      _recording = true;
      _sessionStartedAt = DateTime.now();
      return true;
    } catch (e) {
      _logDebug('iOS録音開始でエラー: $e');
      return false;
    }
  }

  Future<List<TranscriptChunk>> _stopIosRecording(String locale) async {
    _sessionEndedAt = DateTime.now();
    String? path;
    try {
      path = await _captureChannel
          .invokeMethod<String>('stopCapture')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _logDebug('iOS録音停止でエラー: $e');
    }
    _recording = false;
    if (path == null) return const [];
    _lastRecordingPath = path;

    _isTranscribing = true;
    unawaited(ScreenWakeService.instance.acquire(_wakeReasonTranscribing));
    _setTranscribeProgress(0, phaseAnalyzing);
    StreamSubscription<dynamic>? progressSub;
    try {
      progressSub = _progressChannel.receiveBroadcastStream().listen((event) {
        final f = (event as num).toDouble();
        if (f > 1.0) return;
        _setTranscribeProgress(f, phaseAnalyzing);
      });
      final sessionStart =
          _sessionStartedAt ?? _sessionEndedAt ?? DateTime.now();
      final raw = await _captureChannel
          .invokeMethod<List<dynamic>>('transcribeFile', {
            'path': path,
            'locale': locale,
          })
          .timeout(const Duration(seconds: 30));
      _chunks.addAll(
        _chunksFromIosSegments(raw ?? [], sessionStart: sessionStart),
      );
      _setTranscribeProgress(1, phaseAnalyzing);
    } catch (e) {
      _logDebug('iOS文字起こしでエラー: $e');
    } finally {
      await progressSub?.cancel();
      _isTranscribing = false;
      unawaited(ScreenWakeService.instance.release(_wakeReasonTranscribing));
    }
    return List.unmodifiable(_chunks);
  }

  List<TranscriptChunk> _chunksFromIosSegments(
    List<dynamic> segments, {
    required DateTime sessionStart,
  }) {
    if (segments.isEmpty) return const [];
    const phraseBreakGap = 0.8; // 秒: これ以上の語間ポーズで新フレーズ
    final chunks = <TranscriptChunk>[];
    final buf = StringBuffer();
    var phraseStartTs = 0.0;
    var prevEndTs = 0.0;

    for (final raw in segments) {
      final seg = Map<String, dynamic>.from(raw as Map);
      final word = (seg['text'] as String? ?? '').trim();
      if (word.isEmpty) continue;
      final ts = (seg['timestamp'] as num?)?.toDouble() ?? 0.0;
      final dur = (seg['duration'] as num?)?.toDouble() ?? 0.2;

      if (buf.isNotEmpty && ts - prevEndTs > phraseBreakGap) {
        chunks.add(
          TranscriptChunk(
            text: buf.toString().trim(),
            recognizedAt: sessionStart.add(
              Duration(milliseconds: (phraseStartTs * 1000).round()),
            ),
          ),
        );
        buf.clear();
        phraseStartTs = ts;
      }
      if (buf.isEmpty) phraseStartTs = ts;
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(word);
      prevEndTs = ts + dur;
    }
    if (buf.isNotEmpty) {
      chunks.add(
        TranscriptChunk(
          text: buf.toString().trim(),
          recognizedAt: sessionStart.add(
            Duration(milliseconds: (phraseStartTs * 1000).round()),
          ),
        ),
      );
    }
    return chunks;
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Future<bool> _startAndroidRecording() async {
    var permitted = await hasRecordPermission();
    if (!permitted) permitted = await requestRecordPermission();
    if (!permitted) return false;

    try {
      await _configureAndroidCaptureSession();
      await Future.delayed(const Duration(milliseconds: 350));

      final ok = await _captureChannel
          .invokeMethod<bool>('startRecording')
          .timeout(const Duration(seconds: 5));
      if (ok != true) return false;
      _recording = true;
      _sessionStartedAt = DateTime.now();
      return true;
    } catch (e) {
      _logDebug('録音開始でエラー: $e');
      try {
        await _captureChannel
            .invokeMethod<void>('cancelRecording')
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      return false;
    }
  }

  Future<List<TranscriptChunk>> _stopAndroidRecording(
    String locale, {
    required bool allowVoskFallback,
    required bool skipOnlineRecognition,
  }) async {
    _sessionEndedAt = DateTime.now();
    String? wavPath;
    try {
      wavPath = await _captureChannel
          .invokeMethod<String>('stopRecording')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _logDebug('録音停止でエラー: $e');
    }
    _recording = false;

    if (wavPath != null) {
      await _androidTranscribe(
        wavPath,
        locale,
        allowVoskFallback: allowVoskFallback,
        skipOnlineRecognition: skipOnlineRecognition,
      );
      try {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/layer4_recording.wav';
        await File(wavPath).copy(savePath);
        _lastRecordingPath = savePath;
        await File(wavPath).delete();
      } catch (_) {}
    }

    try {
      await _restorePlaybackAudioSession();
    } catch (_) {}

    return List.unmodifiable(_chunks);
  }

  void _setTranscribeProgress(double value, String phase) {
    _transcribeProgress = value.clamp(0.0, 1.0);
    _transcribePhase = phase;
    _progressController.add((progress: _transcribeProgress, phase: phase));
  }

  Future<void> _androidTranscribe(
    String wavPath,
    String locale, {
    required bool allowVoskFallback,
    required bool skipOnlineRecognition,
  }) async {
    _isTranscribing = true;
    unawaited(ScreenWakeService.instance.acquire(_wakeReasonTranscribing));
    _setTranscribeProgress(0, phaseAnalyzing);
    StreamSubscription<dynamic>? progressSub;
    try {
      if (!skipOnlineRecognition) {
        final raw = await _captureChannel
            .invokeMethod<Map>('recognizeOnline', {
              'wavPath': wavPath,
              'locale': locale,
            })
            .timeout(const Duration(seconds: 20));
        final onlineText = (raw?['text'] as String?)?.trim();
        final onlineReason = (raw?['reason'] as String?)?.trim();
        if (onlineText != null && onlineText.isNotEmpty) {
          final started = _sessionStartedAt ?? DateTime.now();
          _chunks.add(
            TranscriptChunk(text: onlineText, recognizedAt: started),
          );
          _setTranscribeProgress(1, phaseAnalyzing);
          _logDebug('オンライン音声認識で完了');
          return;
        }
        if (onlineReason != null && onlineReason.isNotEmpty) {
          _logDebug('オンライン音声認識が空: $onlineReason');
        } else {
          _logDebug('オンライン音声認識が空（理由なし）');
        }
      } else {
        _logDebug('レイヤーⅣ: SpeechRecognizerをスキップしVoskへ');
      }

      // レイヤーⅠ単語テストはSpeechRecognizerのみ。レイヤーⅣ/Ⅴ以外の
      // ロケール（vi-VN/en-US等）もVosk日本語モデルへのフォールバックはしない。
      if (!allowVoskFallback || locale != 'ja-JP') {
        _setTranscribeProgress(1, phaseAnalyzing);
        _logDebug(
          allowVoskFallback
              ? 'オンライン認識が空、かつ$localeはVoskの対象外のため終了'
              : 'オンライン認識が空（SpeechRecognizerのみモード）',
        );
        return;
      }

      // オンライン認識が使えなかった場合、Voskオフライン文字起こしにフォールバックする。
      _logDebug('オンライン認識が空だったため、Voskフォールバックへ移行');
      final modelReady = await VoskModelManager.isReady();
      if (!modelReady) {
        _logDebug('Voskモデルを準備中（初回のみ）');
        _setTranscribeProgress(0, phaseModelPreparing);
        await VoskModelManager.ensureReady(
          onProgress: (p) {
            _setTranscribeProgress(
              p * _modelPrepProgressShare,
              phaseModelPreparing,
            );
          },
        ).timeout(const Duration(minutes: 10));
      }
      final base = modelReady ? 0.0 : _modelPrepProgressShare;
      final span = modelReady ? 1.0 : 1.0 - _modelPrepProgressShare;
      _setTranscribeProgress(base, phaseAnalyzing);

      progressSub = _progressChannel.receiveBroadcastStream().listen((event) {
        final f = (event as num).toDouble();
        if (f > 1.0) {
          _setTranscribeProgress(0, phaseModelLoading); // モデル読み込み中のセンチネル
          return;
        }
        _setTranscribeProgress(base + f * span, phaseAnalyzing);
      });

      final modelPath = await VoskModelManager.modelPath();
      final segments = await _captureChannel
          .invokeMethod<List<dynamic>>('transcribe', {
            'modelPath': modelPath,
            'wavPath': wavPath,
          })
          .timeout(const Duration(seconds: 120));
      _chunks.addAll(_chunksFromAndroidSegments(segments ?? []));
      _setTranscribeProgress(1, phaseAnalyzing);
      _logDebug('Voskフォールバックで完了: ${_chunks.length}件');
    } catch (e) {
      _logDebug('文字起こしでエラー: $e');
    } finally {
      await progressSub?.cancel();
      _isTranscribing = false;
      unawaited(ScreenWakeService.instance.release(_wakeReasonTranscribing));
    }
  }

  List<TranscriptChunk> _chunksFromAndroidSegments(List<dynamic> segments) {
    final started = _sessionStartedAt;
    if (started == null || segments.isEmpty) return const [];
    return segments
        .map((raw) {
          final map = Map<String, dynamic>.from(raw as Map);
          final text = (map['text'] as String? ?? '').trim();
          final startSec = (map['startSec'] as num?)?.toDouble() ?? 0;
          return TranscriptChunk(
            text: text,
            recognizedAt: started.add(
              Duration(milliseconds: (startSec * 1000).round()),
            ),
          );
        })
        .where((chunk) => chunk.text.isNotEmpty)
        .toList(growable: false);
  }

  /// Android STT直前にマイク向けセッションへ切り替える。
  Future<void> _configureAndroidCaptureSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
          flags: AndroidAudioFlags.audibilityEnforced,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
    await session.setActive(true);
  }

  /// 録音済みファイルの聴き直し（just_audio再生）に戻すため、
  /// セッションをplaybackカテゴリーに戻す。
  Future<void> _restorePlaybackAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      ),
    );
    await session.setActive(true);
  }
}
