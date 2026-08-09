import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/vocabulary_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../models/recording_mode.dart';
import '../../models/saved_vocabulary_check.dart';
import '../../models/vocab_answer_mode.dart';
import '../../models/vocab_test_session.dart';
import '../../models/vocabulary_entry.dart';
import '../../models/vocabulary_evaluation.dart';
import '../../models/vocabulary_level.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/jlpt_vocab_bank_service.dart';
import '../../services/learner_answer_language.dart';
import '../../services/recording_stt_service.dart';
import '../../services/vocabulary_ai_response_parser.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/last_recording_playback_mixin.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/level_checkbox_row.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/pronunciation_mic_button.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../../widgets/speech_processing_consent_dialog.dart';
import '../../widgets/vocab_countdown_button.dart';
import '../../widgets/vocabulary_sheet.dart';
import 'vocabulary_check_history_screen.dart';
import 'vocabulary_import_screen.dart';

part 'layer1_vocab_widgets.dart';
part 'layer1_vocab_chrome_ai.dart';
part 'layer1_vocab_help.dart';

/// 単語テストの出題レベル選択状態。「ランダム」（N1/N2/N3/その他すべて対象）
/// か、N1/N2/N3/その他のチェックボックスによる複数選択（1件以上）の
/// どちらか一方を表す。
class _Layer1LevelSelection {
  const _Layer1LevelSelection._({required this.isRandom, required this.levels});

  const _Layer1LevelSelection.random()
    : this._(isRandom: true, levels: const {});

  const _Layer1LevelSelection.levels(Set<VocabularyLevel> levels)
    : this._(isRandom: false, levels: levels);

  final bool isRandom;
  final Set<VocabularyLevel> levels;

  static const _order = [
    VocabularyLevel.n1,
    VocabularyLevel.n2,
    VocabularyLevel.n3,
    VocabularyLevel.other,
  ];

  /// [JlptVocabBankService.loadExamPool]へ渡すレベル集合。
  /// ランダムはnull（＝全レベル対象）。
  Set<VocabularyLevel>? get poolLevels => isRandom ? null : levels;

  /// [_resetStateKey]用の、選択内容を一意に表す文字列。
  String get stateKey => isRandom
      ? 'random'
      : (levels.map((l) => l.storageKey).toList()..sort()).join(',');

  /// [_Layer1LevelField]のトリガー行に表示するラベル。
  String labelText(String lang) {
    if (isRandom) return 'ランダム'.tr(lang);
    return [
      for (final level in _order)
        if (levels.contains(level)) _levelLabelKey(level).tr(lang),
    ].join('・');
  }

  static String _levelLabelKey(VocabularyLevel level) => switch (level) {
    VocabularyLevel.n1 => 'N1レベル',
    VocabularyLevel.n2 => 'N2レベル',
    VocabularyLevel.n3 => 'N3レベル',
    VocabularyLevel.other => '単語帳_レベルその他',
  };
}

/// レイヤーⅠ「語彙を増やす」モードの単語テスト画面。
/// レイヤーⅡ〜Ⅴと同型のフォーム構成（[DiceActionRow] / レベル選択 /
/// 問題カード / サイコロ / [PrepLabelRow] / [GenkiTransportRow]）で、
/// 中央ボタンはレイヤーⅤと同じ[PronunciationMicButton]を使い、
/// サイコロ→（単語抽選・TTS読み上げ）→青マイク（録音待機）→
/// 赤マイク（録音中）→サイコロ、と状態遷移する。
///
/// 1試験＝選択レベルのプールから重複なく抽選した最大10問（レイヤーⅤの
/// [VocabTestSession]と同じ役割分担）。10問すべてに回答すると紙飛行機
/// （送信）が有効になり、レイヤーⅤと同じくChrome AI（Google検索AIモード）
/// へ「期待単語・読み・学習者のSTT回答」のテキストのみを送って参考評価
/// （★1〜5）を受け取る。録音音声そのものは送らない。
///
/// レイヤーⅤと同じ[RecordingMode]（断続/半連続/連続）のトグルを「45」の
/// 位置に置く（[DiceActionRow.fortyFiveIcon]）。タップのたびに
/// 断続→半連続→連続→断続…と巡回する（[appSettings.vocabRecordingMode]。
/// レイヤーⅤの録音モードとは独立して保持する）。
/// - 断続（既定）：サイコロタップで単語を表示してマイクに切り替えるが、
///   録音はマイクをタップするまで始まらない。録音停止後は結果を表示して
///   サイコロに戻り、次の問題へ進むには改めてサイコロをタップする。
/// - 半連続：サイコロタップと同時に録音まで自動的に始まる。停止後の挙動は
///   断続と同じく、サイコロに戻る（次へは改めてサイコロをタップする）。
/// - 連続：サイコロタップ（1問目）または録音停止後に自動的に表示される
///   次の問題（2問目以降）と同時に、TTS読み上げ・録音まで自動的に始まる。
///   そのまま10問目まで進み続ける。
class Layer1VocabScreen extends StatefulWidget {
  const Layer1VocabScreen({super.key, this.onBackToModeSelect});

  /// レイヤーⅠの2択（語彙／耳慣れ）へ戻る。未指定なら戻るボタンを出さない。
  final VoidCallback? onBackToModeSelect;

  @override
  State<Layer1VocabScreen> createState() => Layer1VocabScreenState();
}

class Layer1VocabScreenState extends State<Layer1VocabScreen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin,
        ChromeAiSubmitMixin,
        ResetButtonVisibilityMixin,
        LastRecordingPlaybackMixin {
  final _bankService = JlptVocabBankService();
  final _recordingService = RecordingSttService();
  final _storage = VocabularyCheckStorage();
  final _random = Random();
  final _answerController = TextEditingController();
  late final FocusNode _answerFocusNode;
  _Layer1LevelSelection _levelSelection = const _Layer1LevelSelection.levels({
    VocabularyLevel.n1,
  });
  bool _wordVisible = true;

  /// 学習者が口頭回答する言語（🇻🇳/🇺🇸/🇯🇵トグル）。既定はベトナム語。
  /// 試験途中で切り替えても構わない（次に録音を止めた問題からその言語で
  /// 文字起こしされる）ため、リセット・レベル変更では初期化しない。
  /// キーボード入力では自動判定を使い、この値は音声モード専用。
  LearnerAnswerLanguage _answerLanguage = LearnerAnswerLanguage.vi;

  /// 入力モード切替の検知用（[_onSettingsChanged]）。
  late VocabAnswerMode _lastVocabAnswerMode;

  /// [_requestKeyboardFocus]の post-frame 予約を無効化するための世代番号。
  int _keyboardFocusEpoch = 0;

  /// 現在の10問セッション。[VocabularyService]の読み込みが非同期のため
  /// [initState]では組み立てられず、最初のサイコロタップで遅延生成する
  /// （[_buildSession]）。
  VocabTestSession? _session;
  late String _sessionId;

  /// [PronunciationMicButton]と同じ2状態制。falseならサイコロ（未出題／
  /// 録音停止直後）、trueならマイク（単語を引いて読み上げた直後〜録音中）。
  bool _armed = false;

  /// 録音開始・停止・送信・貼り付けなど、非同期処理中の二重タップ防止
  /// （レイヤーⅤと同じ）。
  bool _actionInFlight = false;
  bool _isSessionSaved = false;
  bool _hasSavedChecks = false;

  /// 回答欄にフォーカスがあるかどうか（ヒント文言などの表示用）。
  bool _answerFieldFocused = false;

  /// キーボード入力モードで回答欄を出しているか。
  /// false のときはサイコロ（未開始・中断の両方）。サイコロタップで true になり、
  /// 空ENTER中断で false に戻る。
  bool _keyboardAnswerUiActive = false;

  /// 回答一覧から過去問を修正している間、修正完了後に戻る問題位置と
  /// その問題で入力途中だった下書きを保持する。
  int? _keyboardEditReturnIndex;
  String? _keyboardEditReturnDraft;

  /// [didChangeMetrics] で検知したソフトキーボード表示中フラグ。
  /// build のたびに [View.viewInsets] を見るだけでなく、変化時だけ setState
  /// して不要な再描画（フォーカス喪失）を避ける。
  bool _softKeyboardVisible = false;

  bool get _recording =>
      _session?.current.status == VocabTestQuestionStatus.recording;

  bool get _allAnswered => _session != null && _session!.allAnswered;

  String _resetStateKey() => [
    _session?.currentIndex.toString() ?? 'none',
    _session?.current.status.name ?? 'none',
    _levelSelection.stateKey,
    _wordVisible.toString(),
    _armed.toString(),
    _allAnswered.toString(),
    chromeAiAwaitingPaste.toString(),
    _isSessionSaved.toString(),
    appSettings.vocabRecordingMode.name,
    _answerLanguage.name,
    _keyboardAnswerUiActive.toString(),
    appSettings.vocabAnswerMode.name,
    _recordingService.lastRecordingPath ?? '',
  ].join('|');

  bool get _showResetButton => showResetButton(_resetStateKey());

  bool get _isKeyboardMode =>
      appSettings.vocabAnswerMode == VocabAnswerMode.keyboard;

  /// Scaffold が resizeToAvoidBottomInset でキーボード分を縮めると、
  /// body 配下の [MediaQuery.viewInsets] は 0 になることがある。
  /// [FlutterView.viewInsets] なら実キーボード高さが取れる。
  double _softKeyboardHeight(BuildContext context) {
    final view = View.maybeOf(context);
    if (view != null) {
      final fromView = view.viewInsets.bottom / view.devicePixelRatio;
      if (fromView > 0) return fromView;
    }
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  /// キーボード入力中の省スペース表示。実キーボード表示中だけ畳む。
  /// 畳むときはウィジェットを木から外さず [Offstage] で隠す
  /// （外すと TextField のフォーカスが切れ、iOS ではキーボードが戻らない）。
  bool _shouldUseCompactKeyboardLayout() {
    if (!_isKeyboardMode ||
        !_keyboardAnswerUiActive ||
        _allAnswered ||
        chromeAiAwaitingPaste) {
      return false;
    }
    return _softKeyboardHeight(context) > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _answerFocusNode = FocusNode();
    _answerFocusNode.addListener(_onAnswerFocusChanged);
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
    _lastVocabAnswerMode = appSettings.vocabAnswerMode;
    _sessionId = _newSessionId();
    unawaited(_loadHasSavedChecks());
    // キーボード入力モードでも、初回描画ではレベル選択・単語帳・サイコロの
    // 通常表示（音声モードと同じ骨格）から始める。サイコロをタップすると
    // 1問目と回答欄・キーボード表示に切り替わる。
    initLastRecordingPlayback();
  }

  String _newSessionId() =>
      'sess_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  Future<void> _loadHasSavedChecks() async {
    final checks = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _hasSavedChecks = checks.isNotEmpty);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answerFocusNode.removeListener(_onAnswerFocusChanged);
    appSettings.removeListener(_onSettingsChanged);
    stopKeepAliveIfOwned();
    _recordingService.dispose();
    disposeLastRecordingPlayback();
    _answerController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_isKeyboardMode) return;
    final visible = _softKeyboardHeight(context) > 0;
    if (visible == _softKeyboardVisible) return;
    setState(() => _softKeyboardVisible = visible);
  }

  void _onAnswerFocusChanged() {
    if (!mounted) return;
    final focused = _answerFocusNode.hasFocus;
    if (focused == _answerFieldFocused) return;
    setState(() => _answerFieldFocused = focused);
  }

  /// キーボード入力モードのサイコロタップ：
  /// - 未開始ならセッションを組み立てて1問目を出す
  /// - 中断中なら同じ問題のまま回答欄へ戻る
  /// いずれの場合も回答欄へフォーカスしてソフトキーボードを表示する
  /// （音声モードのTTS/録音はしない）。
  Future<void> _onKeyboardDiceTap() async {
    if (_actionInFlight || !_isKeyboardMode || _keyboardAnswerUiActive) {
      return;
    }
    if (_session == null) {
      final built = await _buildSession();
      if (!mounted || built == null) return;
      if (_answerController.text.isNotEmpty) {
        _answerController.clear();
      }
    }
    setState(() => _keyboardAnswerUiActive = true);
    // サイコロタップ起点なので、requestFocus でもキーボードを出しやすい。
    _requestKeyboardFocus();
  }

  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    unawaited(_pasteAndSaveResult());
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final keyboard = _isKeyboardMode;
    final switchedOutOfKeyboard =
        !keyboard && _lastVocabAnswerMode == VocabAnswerMode.keyboard;
    _lastVocabAnswerMode = appSettings.vocabAnswerMode;
    setState(() {});
    // キーボードへ切り替えたときに自動フォーカスしない。
    // 開始はサイコロタップに任せる。音声へ戻るときだけフォーカスを外す。
    if (switchedOutOfKeyboard) {
      _answerFocusNode.unfocus();
      setState(() => _answerFieldFocused = false);
    }
  }

  void _requestKeyboardFocus() {
    if (!mounted || !_isKeyboardMode || _allAnswered) return;
    // レイアウト切替直後でも新しく載った TextField にフォーカスが付くよう、
    // 次フレームで requestFocus する。
    final requestId = ++_keyboardFocusEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isKeyboardMode ||
          _allAnswered ||
          requestId != _keyboardFocusEpoch) {
        return;
      }
      if (!_answerFocusNode.hasFocus) {
        _answerFocusNode.requestFocus();
      }
    });
  }

  /// 保留中の自動フォーカスを無効化し、コンパクト表示を解除する。
  void _releaseKeyboardFocus({bool updateState = true}) {
    _keyboardFocusEpoch++;
    _answerFocusNode.unfocus();
    if (!updateState || !mounted) return;
    setState(() => _answerFieldFocused = false);
  }

  /// 回答欄のヒント（入力中のみ表示。中断中はサイコロに戻るため使わない）。
  String _keyboardAnswerHint(String lang) {
    return 'レイヤーⅠ_語彙_回答入力'.tr(lang);
  }

  /// キーボード入力モード：ENTERで回答送信。空のENTERは中断（サイコロ表示に戻る）。
  /// 過去問の修正は回答欄横の「回答を修正」から行う。
  /// 開始／再開はサイコロタップ（[_onKeyboardDiceTap]）。
  Future<void> _onKeyboardSubmit() async {
    if (_actionInFlight || !_isKeyboardMode) return;

    final session = _session;
    if (session == null || _allAnswered) return;

    final text = _answerController.text.trim();
    // 回答一覧から開いた修正中は、空ENTERを「中断」ではなく
    // 「修正を取り消して元の問題へ戻る」として扱う。
    if (text.isEmpty && _keyboardEditReturnIndex != null) {
      _returnFromKeyboardAnswerEdit();
      return;
    }
    // 空欄でENTER → キーボードを閉じてサイコロ（中断）に戻る。
    if (text.isEmpty) {
      _keyboardFocusEpoch++;
      _answerFocusNode.unfocus();
      setState(() {
        _answerFieldFocused = false;
        _keyboardAnswerUiActive = false;
        _softKeyboardVisible = false;
      });
      return;
    }

    setState(() {
      // 音声入力と同じく、回答言語ボタン（🇻🇳/🇺🇸/🇯🇵）の選択を採点言語にする。
      session.completeWithResult(
        text,
        answerLanguageCode: _answerLanguage.code,
      );
      _answerController.clear();
    });

    if (!mounted) return;

    if (_keyboardEditReturnIndex != null) {
      _returnFromKeyboardAnswerEdit();
      return;
    }

    if (session.hasNext) {
      setState(() => session.next());
      _requestKeyboardFocus();
    } else {
      _keyboardFocusEpoch++;
      _answerFocusNode.unfocus();
      setState(() {
        _answerFieldFocused = false;
        _keyboardAnswerUiActive = false;
      });
    }
  }

  Future<void> _openKeyboardAnswerReview() async {
    final session = _session;
    if (session == null) return;

    final returnIndex = session.currentIndex;
    final returnDraft = _answerController.text.trim();
    _releaseKeyboardFocus(updateState: false);
    final selectedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _KeyboardAnswerReviewScreen(
          questions: session.questions,
          lang: appSettings.language,
        ),
      ),
    );
    if (!mounted) return;

    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= session.questionCount) {
      _answerController.value = TextEditingValue(
        text: returnDraft,
        selection: TextSelection.collapsed(offset: returnDraft.length),
      );
      _requestKeyboardFocus();
      return;
    }

    final selected = session.questions[selectedIndex];
    final answer = selected.sttResult ?? '';
    setState(() {
      _keyboardEditReturnIndex = returnIndex;
      _keyboardEditReturnDraft = returnDraft;
      session.currentIndex = selectedIndex;
      session.reopenCurrentForEditing();
      _answerController.value = TextEditingValue(
        text: answer,
        selection: TextSelection.collapsed(offset: answer.length),
      );
      _keyboardAnswerUiActive = true;
    });
    _requestKeyboardFocus();
  }

  void _returnFromKeyboardAnswerEdit() {
    final session = _session;
    final returnIndex = _keyboardEditReturnIndex;
    if (session == null || returnIndex == null) return;
    final draft = _keyboardEditReturnDraft ?? '';

    setState(() {
      // 空ENTERで修正を取り消した場合も、元の回答は残っているので完了状態へ戻す。
      if (session.current.sttResult?.isNotEmpty ?? false) {
        session.current.status = VocabTestQuestionStatus.completed;
      }
      session.currentIndex = returnIndex;
      _keyboardEditReturnIndex = null;
      _keyboardEditReturnDraft = null;
      _answerController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    });
    _requestKeyboardFocus();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 実機のネイティブ録音・文字起こしは Flutter widget test 上で再現できない
  // ため、レイヤーⅤ（[Layer5ScreenState]）と同じく、状態を覗く・ネイティブ
  // 録音を経由せず状態遷移させるためのフックのみを用意する。

  @visibleForTesting
  bool get debugArmed => _armed;

  @visibleForTesting
  bool get debugRecording => _recording;

  @visibleForTesting
  VocabTestSession? get debugSession => _session;

  /// この問の「期待単語」。
  @visibleForTesting
  VocabularyEntry? get debugDrawnWord => _session?.current.entry;

  @visibleForTesting
  String? get debugLastSttAnswer => _session?.current.sttResult;

  /// 画面上の回答言語ボタンで選ばれている言語コード（'vi' / 'en' / 'ja'）。
  @visibleForTesting
  String get debugAnswerLanguageCode => _answerLanguage.code;

  /// 直前に完了した問の [VocabTestQuestion.answerLanguageCode]
  /// （キーボード／音声とも回答言語ボタンの選択が記録される）。
  @visibleForTesting
  String? get debugLastAnswerLanguageCode {
    final session = _session;
    if (session == null) return null;
    for (var i = session.currentIndex; i >= 0; i--) {
      final code = session.questions[i].answerLanguageCode;
      if (code != null) return code;
    }
    return null;
  }

  /// キーボード入力モードで、回答欄フォーカス／ソフトキーボード表示により
  /// レベル選択・単語帳などの通常表示を畳んだコンパクト表示中かどうか。
  @visibleForTesting
  bool get debugCompactKeyboardLayout => _debugForceCompactKeyboardLayout;

  @visibleForTesting
  bool get debugAnswerFieldFocused => _answerFocusNode.hasFocus;

  /// ソフトキーボード表示時のコンパクトレイアウトを強制する（widget test用）。
  @visibleForTesting
  void debugSetKeyboardInsetVisible(bool visible) {
    setState(() => _debugForceCompactKeyboardLayout = visible);
  }

  bool _debugForceCompactKeyboardLayout = false;

  /// ネイティブの録音を経由せず、armed（マイク）状態を録音中（背景赤）にする
  /// （レイヤーⅤの[Layer5ScreenState.debugForceRecordingStatus]と同じ目的）。
  @visibleForTesting
  void debugForceRecording() {
    setState(() => _session?.setStatus(VocabTestQuestionStatus.recording));
  }

  /// ネイティブ録音・STTを経由せず、この問を「STT回答済み」にしてサイコロへ
  /// 戻す（レイヤーⅤの[Layer5ScreenState.debugCompleteCurrentQuestion]と
  /// 同じ目的）。
  @visibleForTesting
  void debugCompleteWithSttAnswer(String answer) {
    setState(() {
      _session?.completeWithResult(
        answer,
        answerLanguageCode: _answerLanguage.code,
      );
      _armed = false;
    });
  }

  /// キーボード入力のENTER送信を、ネイティブIMEを経由せず再現する。
  @visibleForTesting
  Future<void> debugSubmitKeyboardAnswer(String answer) async {
    _answerController.text = answer;
    await _onKeyboardSubmit();
  }

  void _toggleWordVisible() => setState(() => _wordVisible = !_wordVisible);

  void _toggleAnswerLanguage() =>
      setState(() => _answerLanguage = _answerLanguage.next);

  /// 回答言語ボタン長押し：キーボード入力／音声入力を切り替える。
  Future<void> _showInputModePicker() async {
    final lang = appSettings.language;
    final picked = await showModalBottomSheet<VocabAnswerMode>(
      context: context,
      builder: (context) {
        final palette = AppColors.current;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'レイヤーⅠ_語彙_入力モード選択'.tr(lang),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.mic_rounded,
                  color: palette.textOnCardPrimary,
                ),
                title: Text('レイヤーⅠ_語彙_音声入力'.tr(lang)),
                trailing: appSettings.vocabAnswerMode == VocabAnswerMode.voice
                    ? Icon(Icons.check, color: palette.accentColor)
                    : null,
                onTap: () => Navigator.pop(context, VocabAnswerMode.voice),
              ),
              ListTile(
                leading: Icon(
                  Icons.keyboard_rounded,
                  color: palette.textOnCardPrimary,
                ),
                title: Text('レイヤーⅠ_語彙_キーボード入力'.tr(lang)),
                trailing:
                    appSettings.vocabAnswerMode == VocabAnswerMode.keyboard
                    ? Icon(Icons.check, color: palette.accentColor)
                    : null,
                onTap: () => Navigator.pop(context, VocabAnswerMode.keyboard),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked == appSettings.vocabAnswerMode) return;
    appSettings.vocabAnswerMode = picked;
    // 入力方式が変わったら途中の試験はやり直す。
    await _resetAttempt();
    if (!mounted) return;
    // 切替直後にコンパクト表示へ入らないよう、フォーカス予約も破棄する。
    _releaseKeyboardFocus();
  }

  /// 録音モードを断続→半連続→連続→断続…の順で切り替える
  /// （レイヤーⅤの[Layer5ScreenState]と同じ切り替え方式）。
  void _toggleRecordingMode() {
    setState(() {
      appSettings.vocabRecordingMode = appSettings.vocabRecordingMode.next;
    });
  }

  Future<void> _selectLevel() async {
    if (_actionInFlight) return;
    await _Layer1LevelSelectSheet.show(
      context,
      selected: _levelSelection,
      onChanged: (selection) => unawaited(_applyLevelSelection(selection)),
    );
  }

  /// レベル選択シートでの選択（チェックボックスの切り替え・「ランダム」の
  /// 選択）のたびに呼ばれ、即座に反映する（[EpisodeSortSheet]と同じ、
  /// シートを開いたまま調整を続けられる方式）。
  Future<void> _applyLevelSelection(_Layer1LevelSelection selection) async {
    // 録音中にレベルを切り替えたら、中途半端な録音を残さずキャンセルする。
    if (_recording) await _recordingService.cancel();
    if (!mounted) return;
    // 貼り付け待ち中のレベル変更は、リセットと同様に keep-alive も止める
    // （フラグだけ消すと無音再生が残る）。
    if (chromeAiAwaitingPaste) {
      stopKeepAliveIfOwned();
    }
    // レイヤーⅡの分野変更と同じく、レベルを切り替えたら試験をやり直す
    // （古いレベルのセッションが残って見えないようにするため）。
    // マイク状態（armed/recording）もサイコロに戻す。
    setState(() {
      _levelSelection = selection;
      _session = null;
      _sessionId = _newSessionId();
      _armed = false;
      chromeAiAwaitingPaste = false;
      _isSessionSaved = false;
      chromeAiPendingSentPrompt = null;
      _keyboardAnswerUiActive = false;
      _keyboardEditReturnIndex = null;
      _keyboardEditReturnDraft = null;
      _answerController.clear();
    });
    // キーボードモードではレベル変更後も「サイコロで開始」に揃える
    // （自動フォーカス／自動開始はしない）。
    if (_isKeyboardMode) {
      _releaseKeyboardFocus();
    }
  }

  /// [selection]に該当する単語プールを読み込む。「ランダム」はN1/N2/N3/
  /// その他すべて。レベルを指定した場合は、チェックボックスで明示的に
  /// 選ばれたレベルの語だけに絞る（[JlptVocabBankService.loadExamPool]
  /// 参照）。設定で標準語彙がONなら[JlptVocabularyBank]もマージする。
  Future<List<VocabularyEntry>> _poolForLevel(_Layer1LevelSelection selection) {
    return _bankService.loadExamPool(
      levels: selection.poolLevels,
      includeDefaults: appSettings.includeDefaultVocabulary,
    );
  }

  /// 中央ボタンのタップ本体（[PronunciationMicButton.onTap]）。
  /// - サイコロ表示中：[_onDiceTap]（セッションを生成・または次の問題へ
  ///   進めてマイクへ切り替える）。
  /// - マイク表示中・録音していない：[_startRecording]（録音開始）。
  /// - マイク表示中・録音中（背景が赤）：[_stopRecordingAndTranscribe]
  ///   （録音終了→STT→サイコロに戻す）。
  void _onMicButtonTap() {
    if (_actionInFlight) return;
    if (!_armed) {
      unawaited(_onDiceTap());
    } else if (_recording) {
      unawaited(_stopRecordingAndTranscribe());
    } else {
      unawaited(_startRecording());
    }
  }

  /// サイコロタップ：まだセッションが無ければ選択レベルのプールから重複なく
  /// 最大10問を抽選してセッションを組み立てる（[_buildSession]）。既に
  /// セッションがあり現在の問題が回答済みなら、次の問題へ進める（最後の
  /// 問題まで答え終わっていれば何もしない＝[_allAnswered]により、以後は
  /// ボタンごと隠れて送信ボタンに役目を譲る）。いずれの場合も、表示する
  /// 単語をTTSで読み上げてからマイク（録音待機）に切り替える。
  Future<void> _onDiceTap() async {
    if (_actionInFlight) return;
    var session = _session;
    if (session == null) {
      session = await _buildSession();
      if (!mounted || session == null) return;
    } else {
      final status = session.current.status;
      final answered =
          status == VocabTestQuestionStatus.completed ||
          status == VocabTestQuestionStatus.failed;
      if (answered) {
        if (!session.hasNext) return;
        setState(() => session!.next());
      }
    }
    setState(() => _armed = true);
    final entry = session.current.entry;
    final text = entry.reading.isNotEmpty ? entry.reading : entry.word;
    // 読み上げが終わるまで待ってから次の動作（半連続/連続モードの自動録音
    // 開始）へ進む。先に録音を始めてしまうと（[_startRecording]内の
    // [topicSpeechReader.stop]によって）読み上げが即座に打ち切られてしまう。
    await topicSpeechReader.speak(text: text);
    if (!mounted) return;
    await _autoStartRecording();
  }

  /// 断続モード以外（半連続/連続）のときだけ、問題が表示され次第自動的に
  /// 録音を開始する（断続モードでは、マイクをタップするまで録音を始めない）。
  Future<void> _autoStartRecording() async {
    if (!appSettings.vocabRecordingMode.autoStartsRecording) return;
    if (!mounted || !_armed || _recording) return;
    await _startRecording();
  }

  /// 選択レベルのプールから重複なく最大10問を抽選し、新しいセッションを
  /// 組み立てて[_session]にセットする（同一試験内の重複を避けるため
  /// シャッフルしたプールの先頭から取る）。プールが空なら案内を出して
  /// nullを返す。
  ///
  /// 開始時に余分な setState をすると、キーボード入力中にソフトキーボードが
  /// 閉じることがあるため、[_actionInFlight]の立て下げは必要最小限にする。
  Future<VocabTestSession?> _buildSession() async {
    if (_actionInFlight) return null;
    _actionInFlight = true;
    try {
      final pool = await _poolForLevel(_levelSelection);
      if (!mounted) return null;
      if (pool.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レイヤーⅠ_語彙_プール空'.tr(appSettings.language))),
        );
        return null;
      }
      final shuffled = List<VocabularyEntry>.of(pool)..shuffle(_random);
      final session = VocabTestSession(
        questions: [
          for (final entry in shuffled.take(10))
            VocabTestQuestion(entry: entry),
        ],
      );
      if (!mounted) return null;
      setState(() => _session = session);
      return session;
    } finally {
      _actionInFlight = false;
    }
  }

  /// 青マイクタップ：同意を確認してから録音を開始し、背景を赤にする
  /// （[RecordingSttService]・同意ダイアログはレイヤーⅤと同じもの）。
  Future<void> _startRecording() async {
    setState(() => _actionInFlight = true);
    try {
      await topicSpeechReader.stop();
      if (!mounted) return;
      final consented = await SpeechProcessingConsentDialog.ensure(
        context,
        appSettings.language,
      );
      if (!consented || !mounted) return;
      final started = await _recordingService.startRecording();
      if (!mounted) return;
      if (!started) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('マイク権限なし'.tr(appSettings.language))),
        );
        return;
      }
      setState(() => _session?.setStatus(VocabTestQuestionStatus.recording));
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  /// 赤マイクタップ：録音を終了してSTTでテキスト化し、この問の結果として
  /// セッションに記録する。ここから先はモードで分岐する
  /// （レイヤーⅤの[Layer5ScreenState._onMicTapToStop]と同じ考え方）：
  /// - 連続モード：サイコロを経由せず自動的に次の問題へ進め、TTS読み上げと
  ///   録音も自動的に始める。次の問題がなければ（10問目だった場合）armedを
  ///   falseに戻す（送信ボタンに役目を譲るため、[_allAnswered]により
  ///   表示ごと隠れる）。
  /// - 断続・半連続モード：次の問題へは進めず、armedをfalseに戻して
  ///   サイコロを表示する。次の問題へ進むには改めてサイコロをタップする。
  Future<void> _stopRecordingAndTranscribe() async {
    await _stopRecordingAndSetResult();
    if (!mounted) return;
    if (!appSettings.vocabRecordingMode.autoAdvancesQuestions) {
      setState(() => _armed = false);
      return;
    }
    final session = _session;
    if (session == null || !session.hasNext) {
      setState(() => _armed = false);
      return;
    }
    await stopLastRecordingPlayback();
    if (!mounted) return;
    setState(() {
      session.next();
      _armed = true;
    });
    final entry = session.current.entry;
    final text = entry.reading.isNotEmpty ? entry.reading : entry.word;
    // 読み上げが終わるまで待ってから次の問題の自動録音を始める
    // （[_onDiceTap]と同じ理由）。
    await topicSpeechReader.speak(text: text);
    if (!mounted) return;
    await _autoStartRecording();
  }

  /// 録音中に赤マイクの代わりに表示する[VocabCountdownButton]の
  /// タップ／0秒到達の両方から呼ばれる。
  Future<void> _onVocabCountdownFinished() async {
    if (_actionInFlight || !_recording) return;
    await _stopRecordingAndTranscribe();
  }

  /// 録音を終了してSTTでテキスト化し、この問の結果としてセッションに
  /// 記録する（armed状態の扱いは呼び出し元の[_stopRecordingAndTranscribe]
  /// に任せる）。
  Future<void> _stopRecordingAndSetResult() async {
    setState(() => _actionInFlight = true);
    try {
      final chunks = await _recordingService.stopAndTranscribe(
        locale: _answerLanguage.localeTag,
        allowVoskFallback: _answerLanguage == LearnerAnswerLanguage.ja,
      );
      if (!mounted) return;
      final text = chunks.map((chunk) => chunk.text).join('').trim();
      setState(() {
        if (text.isEmpty) {
          _session?.markFailed();
        } else {
          _session?.completeWithResult(
            text,
            answerLanguageCode: _answerLanguage.code,
          );
        }
      });
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'うまく聞き取れませんでした。もう一度録音してみましょう。'.tr(appSettings.language),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  /// レイヤー離脱時：録音・TTS・再生・keep-aliveを止める（試験セッションは残す）。
  /// [MainShellState._selectLayer]がレイヤーⅠから他レイヤーへ切り替える直前に
  /// 呼び出す。リセット（[_resetAttempt]）と異なり、試験の進行状況
  /// （[_session]・[chromeAiAwaitingPaste]・回答済みの各問）はそのまま残し、
  /// 戻ってきたときに続きから再開できるようにする。
  Future<void> pauseBackgroundActivity() async {
    await topicSpeechReader.stop();
    await stopLastRecordingPlayback();
    await _recordingService.cancel();
    stopKeepAliveIfOwned();
    if (!mounted) return;
    setState(() {
      // 録音中のまま離脱すると、戻ってきても止まった録音が残ってしまうため
      // waitingへ戻す（回答は未確定のまま。改めて録音し直してもらう）。
      if (_session?.current.status == VocabTestQuestionStatus.recording) {
        _session!.setStatus(VocabTestQuestionStatus.waiting);
      }
      _armed = false;
    });
  }

  /// 「再生」タップ：直近の録音を再生⇄一時停止する。録音が無ければ何もしない。
  Future<void> _togglePlayback() async {
    if (_actionInFlight) return;
    await toggleLastRecordingPlayback(_recordingService.lastRecordingPath);
  }

  /// 紙飛行機（送信）タップ：10問すべての「期待単語・読み・学習者のSTT
  /// 回答」をテキストのみでプロンプトに組み立て、Chrome AI（Google検索
  /// AIモード）へ送る。録音音声そのものは送らない（レイヤーⅤと同じ）。
  ///
  /// [chromeAiSend]自体が[chromeAiActionInFlight]の二重タップ防止を持つため、
  /// ここでは[_actionInFlight]で包まない（ダッシュボードと同じ）。
  Future<void> _sendToChromeAi() async {
    final session = _session;
    if (_actionInFlight ||
        chromeAiAwaitingPaste ||
        session == null ||
        !session.allAnswered ||
        _isSessionSaved) {
      return;
    }
    final lang = appSettings.language;
    final launch = VocabularyAiPromptTemplate.evaluationLaunch(
      questions: session.questions,
      lang: lang,
      keyboardInput: _isKeyboardMode,
    );
    await chromeAiSend(
      lang: lang,
      prompt: launch.prompt,
      url: launch.url,
      requiresClipboardPaste: launch.requiresClipboardPaste,
    );
  }

  /// クリップボードのChrome AI回答を解析して保存する（レイヤーⅤと同じく、
  /// Chromeから戻ったタイミングで自動実行。緑の貼り付けボタンからも呼べる）。
  /// 解析に失敗した場合でも回答原文は[SavedVocabularyCheck.unparsedResponse]
  /// として残す。排他は[runChromeAiPaste]（[chromeAiActionInFlight]）に任せる。
  Future<void> _pasteAndSaveResult() async {
    final session = _session;
    if (session == null) return;
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      if (!mounted || text == null) return;

      final parseResult = VocabularyAiResponseParser.parse(
        text,
        languageCode: chromeAiPendingResponseLanguage,
      );

      final now = DateTime.now();
      if (!parseResult.isSuccess) {
        showChromeAiMessage('Chrome AIの回答を解析できませんでした'.tr(lang));
        final saved = SavedVocabularyCheck.fromSession(
          id: '${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}',
          sessionId: _sessionId,
          createdAt: now,
          session: session,
          evaluation: null,
          unparsedResponse: text,
        );
        await _storage.save(saved);
        if (!mounted) return;
        setState(() {
          _isSessionSaved = true;
          _hasSavedChecks = true;
        });
        clearChromeAiPendingState();
        return;
      }

      final saved = SavedVocabularyCheck.fromSession(
        id: '${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}',
        sessionId: _sessionId,
        createdAt: now,
        session: session,
        evaluation: parseResult.evaluation,
        unparsedResponse: null,
      );
      await _storage.save(saved);
      if (!mounted) return;
      setState(() {
        _isSessionSaved = true;
        _hasSavedChecks = true;
      });
      clearChromeAiPendingState();
      final evaluation = parseResult.evaluation;
      if (evaluation != null) {
        unawaited(_showResultDialog(evaluation));
      }
    });
  }

  Future<void> _onSubmitTap() => chromeAiOnSubmitTap(
    onSend: _sendToChromeAi,
    onPaste: _pasteAndSaveResult,
  );

  /// 保存した評価を、★表示と各問の正誤・フィードバックを添えた簡易
  /// ダイアログでその場で表示する（レイヤーⅤの結果体験に近づける）。
  /// 過去分をまとめて見るには単語帳アイコンの隣の「語彙力評価結果」アイコンから
  /// [VocabularyCheckHistoryScreen]を開く（[_openHistory]）。
  Future<void> _showResultDialog(VocabularyEvaluation evaluation) async {
    if (!mounted) return;
    final lang = appSettings.language;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _VocabResultDialog(
        evaluation: evaluation,
        session: _session,
        lang: lang,
      ),
    );
  }

  /// 「語彙力評価結果」アイコンタップ：これまでの単語テスト結果一覧を開く
  /// （レイヤーⅤの「発音チェック結果」アイコンと同じ動線）。
  Future<void> _openHistory() async {
    await VocabularyCheckHistoryScreen.push(context);
    await _loadHasSavedChecks();
  }

  /// 「リセット」タップ：読み上げ・録音・再生を即座に中止し、新しい試験
  /// （セッション未生成の状態）に戻す（レイヤーⅤの`resetAttempt`相当）。
  Future<void> _resetAttempt() async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await topicSpeechReader.stop();
      await stopLastRecordingPlayback();
      await _recordingService.cancel();
      await _recordingService.clearLastRecording();
      stopKeepAliveIfOwned();
      if (!mounted) return;
      // キーボード入力モードでは、リセット後にそのままキーボードへ再フォーカス
      // せず、レベル選択・単語帳などが見える通常表示（初回描画と同じ画面）に
      // 戻す。ユーザーが改めて回答欄をタップしたときだけキーボードが出る。
      _releaseKeyboardFocus(updateState: false);
      setState(() {
        _session = null;
        _sessionId = _newSessionId();
        _armed = false;
        chromeAiAwaitingPaste = false;
        _isSessionSaved = false;
        chromeAiPendingResponseLanguage = 'ja';
        chromeAiPendingSentPrompt = null;
        _answerController.clear();
        _answerFieldFocused = false;
        _keyboardAnswerUiActive = false;
        _keyboardEditReturnIndex = null;
        _keyboardEditReturnDraft = null;
        _softKeyboardVisible = false;
        _debugForceCompactKeyboardLayout = false;
        hideResetUntilNextChange(_resetStateKey());
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  /// 「＋」タップ：Chrome AI で語彙を自動生成して取り込む画面を開く
  /// （レイヤーⅡのお題取り込み・レイヤーⅤの発音課題取り込みと同型）。
  Future<void> _openVocabImport() async {
    await VocabularyImportScreen.push(context);
  }

  /// 「＋」長押し：単語テスト画面の各ボタンの使い方を表示する。
  void _showUsageHelp() {
    showLayer1VocabUsageHelp(
      context,
      lang: appSettings.language,
      isKeyboardMode: _isKeyboardMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final session = _session;
    final showSubmit = _allAnswered && !_isSessionSaved;
    final submitEnabled =
        !_actionInFlight &&
        !chromeAiActionInFlight &&
        (showSubmit || chromeAiAwaitingPaste);
    final compactKeyboardLayout =
        _debugForceCompactKeyboardLayout || _shouldUseCompactKeyboardLayout();
    final hasAnsweredQuestion =
        session?.questions.any(
          (question) => question.sttResult?.isNotEmpty ?? false,
        ) ??
        false;
    return Container(
      color: palette.scene,
      child: SafeArea(
        bottom: !compactKeyboardLayout,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compactKeyboardLayout ? 16 : 20,
            compactKeyboardLayout ? 4 : 16,
            compactKeyboardLayout ? 16 : 20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // キーボード表示中は木から外さず隠す（外すと回答欄のフォーカスが切れる）。
              ExcludeFocus(
                excluding: compactKeyboardLayout,
                child: Offstage(
                  offstage: compactKeyboardLayout,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceActionRow(
                        // キーボード入力では録音モード・単語表示切替は使わないので隠す
                        // （枠は確保して回答言語／＋の位置がズレないようにする）。
                        show45: !_isKeyboardMode,
                        show60: !_isKeyboardMode,
                        show15Plus60: true,
                        // 断続/半連続/連続の録音モードトグル（レイヤーⅤの録音モード
                        // ボタンを流用）。タップのたびに断続→半連続→連続→断続…と
                        // 巡回する（[RecordingModeX.next]）。
                        fortyFiveIcon: switch (appSettings.vocabRecordingMode) {
                          RecordingMode.intermittent =>
                            Icons.more_horiz_rounded,
                          RecordingMode.semiContinuous =>
                            Icons.linear_scale_rounded,
                          RecordingMode.continuous =>
                            Icons.horizontal_rule_rounded,
                        },
                        fortyFiveTooltip:
                            switch (appSettings.vocabRecordingMode) {
                              RecordingMode.intermittent => '断続モード',
                              RecordingMode.semiContinuous => '半連続モード',
                              RecordingMode.continuous => '連続モード',
                            },
                        fortyFiveActive:
                            appSettings.vocabRecordingMode !=
                            RecordingMode.intermittent,
                        // 断続＝透明（非active時の既定表示）、半連続＝青、連続＝橙で
                        // 一目でモードを見分けられるようにする（レイヤーⅤと同じ配色）。
                        fortyFiveActiveFill: switch (appSettings
                            .vocabRecordingMode) {
                          RecordingMode.intermittent => null,
                          RecordingMode.semiContinuous => palette.accentColor,
                          RecordingMode.continuous => palette.cardAccent,
                        },
                        // 余白ゼロ・枠線なしで、アイコンをできるだけ大きく表示する
                        // （国旗・目のアイコン等と同じ差し替え方式）。
                        fortyFiveShowBorder: false,
                        fortyFiveHorizontalPadding: 0,
                        fortyFiveIconSize: 48,
                        onFortyFiveTap: _toggleRecordingMode,
                        // 問題表示/非表示トグル（旧「45」位置から移動）。国旗ボタンと
                        // 同じく、余白ゼロ・枠線なし・アイコン大。ON/OFFはアイコン
                        // 差し替えだけで伝え、active塗りは使わない（背景は常に
                        // 透明＝scene同化）。
                        sixtyIcon: _wordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        sixtyTooltip: 'レイヤーⅠ_語彙_単語表示切替',
                        sixtyShowBorder: false,
                        sixtyHorizontalPadding: 0,
                        sixtyIconSize: 48,
                        onSixtyTap: _toggleWordVisible,
                        // 口頭回答の言語トグル（🇻🇳→🇺🇸→🇯🇵）。長押しで
                        // キーボード入力／音声入力を切り替える。
                        fifteenSixtyLabel: _answerLanguage.flag,
                        fifteenSixtyTooltip: 'レイヤーⅠ_語彙_回答言語切替',
                        fifteenSixtyShowBorder: false,
                        fifteenSixtyHorizontalPadding: 0,
                        fifteenSixtyLabelFontSize: 56,
                        onFifteenSixtyTap: _toggleAnswerLanguage,
                        onFifteenSixtyLongPress: () =>
                            unawaited(_showInputModePicker()),
                        showAdd: true,
                        addIcon: Icons.add_rounded,
                        addTooltip: '語彙を追加',
                        onAddTap: _openVocabImport,
                        onAddLongPress: _showUsageHelp,
                      ),
                      const SizedBox(height: 4),
                      _Layer1LevelField(
                        selection: _levelSelection,
                        onTap: _selectLevel,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Layer1WordCard(
                        word: session?.current.entry,
                        wordVisible: _isKeyboardMode ? true : _wordVisible,
                        keyboardAwaitingStart:
                            _isKeyboardMode && session == null,
                        questionNumber: session == null
                            ? null
                            : session.currentIndex + 1,
                        totalQuestions: session?.questionCount,
                        compact: compactKeyboardLayout,
                      ),
                      if (chromeAiAwaitingPaste) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Chromeから戻ったら貼り付けボタンを押して、語彙力評価結果を保存しよう'.tr(lang),
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textOnSceneSecondary,
                          ),
                        ),
                      ],
                      if (_isKeyboardMode &&
                          compactKeyboardLayout &&
                          session != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'レイヤーⅠ_語彙_ENTERで中断'.tr(lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textOnSceneSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 音声モード：サイコロ／マイク。
              // キーボードモード：未開始・中断はサイコロ、入力中は同じ位置に回答欄。
              Visibility(
                visible: !_allAnswered && !chromeAiAwaitingPaste,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _isKeyboardMode
                    ? (_keyboardAnswerUiActive
                          ? KeyedSubtree(
                              key: const ValueKey(
                                'layer1_keyboard_answer_field',
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _Layer1KeyboardAnswerField(
                                      controller: _answerController,
                                      focusNode: _answerFocusNode,
                                      hintText: _keyboardAnswerHint(lang),
                                      onSubmit: () =>
                                          unawaited(_onKeyboardSubmit()),
                                      compact: compactKeyboardLayout,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IgnorePointer(
                                    ignoring: !hasAnsweredQuestion,
                                    child: Opacity(
                                      opacity: hasAnsweredQuestion ? 1 : 0,
                                      child: IconButton(
                                        key: const ValueKey(
                                          'review_keyboard_answers_button',
                                        ),
                                        onPressed: () => unawaited(
                                          _openKeyboardAnswerReview(),
                                        ),
                                        tooltip: 'レイヤーⅠ_語彙_回答を修正'.tr(lang),
                                        icon: const Icon(
                                          Icons.edit_note_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: PronunciationMicButton(
                                armed: false,
                                recording: false,
                                onTap: () => unawaited(_onKeyboardDiceTap()),
                                size: 98,
                              ),
                            ))
                    : Center(
                        child: _recording
                            ? VocabCountdownButton(
                                onTapEarlyFinish: () =>
                                    unawaited(_onVocabCountdownFinished()),
                                onCountdownZero: () =>
                                    unawaited(_onVocabCountdownFinished()),
                                size: 98,
                              )
                            : PronunciationMicButton(
                                armed: _armed,
                                recording: _recording,
                                onTap: _onMicButtonTap,
                                size: 98,
                              ),
                      ),
              ),
              ExcludeFocus(
                excluding:
                    compactKeyboardLayout &&
                    !showSubmit &&
                    !chromeAiAwaitingPaste,
                child: Offstage(
                  offstage:
                      compactKeyboardLayout &&
                      !showSubmit &&
                      !chromeAiAwaitingPaste,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      // 「理由」枠に単語カードアイコンを置き、単語帳を開く導線にする
                      // （レイヤーⅠの2択画面「語彙を増やす」と同じ Icons.style_rounded）。
                      // 「結論」「例示」は枠だけ確保した非表示状態で置いておく。
                      PrepLabelRow(
                        showReason: true,
                        reasonIcon: Icons.style_rounded,
                        reasonTooltip: '単語帳',
                        reasonShowBorder: false,
                        reasonHorizontalPadding: 0,
                        // 出題中の単語があれば、単語帳を開いたときにその語のカードを
                        // 直接表示する（例：「促進」を出題中に開いたら「促進」が見える）。
                        onReasonTap: () => VocabularySheet.show(
                          context,
                          focusEntryId: session?.current.entry.id,
                        ),
                        // 単語帳の隣に、レイヤーⅤの「発音チェック結果」と同じ動線で
                        // 単語テスト結果の履歴を開けるボタンを置く。保存済み結果が
                        // あるときだけ表示し、青地で強調する。
                        showExample: _hasSavedChecks,
                        exampleIcon: Icons.list_alt_rounded,
                        exampleTooltip: '語彙力評価結果',
                        exampleActive: _hasSavedChecks,
                        onExampleTap: _openHistory,
                      ),
                      const SizedBox(height: 8),
                      GenkiTransportRow(
                        // キーボード入力では録音再生は使わないので隠す。
                        showPlay: !_isKeyboardMode,
                        showReset: _showResetButton,
                        showDiagnose: showSubmit || chromeAiAwaitingPaste,
                        playing: isPlayingLastRecording,
                        // レイヤーⅣ/Ⅴと同じく、直近の録音が残っている間は再生ボタンを
                        // 青地で強調する。
                        playHasData:
                            _recordingService.lastRecordingPath != null,
                        diagnoseHighlighted:
                            showSubmit && !chromeAiAwaitingPaste,
                        diagnoseAwaitingPaste: chromeAiAwaitingPaste,
                        onPlay: _togglePlayback,
                        onReset: _resetAttempt,
                        onDiagnose: submitEnabled ? _onSubmitTap : null,
                        languageCode: lang,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
