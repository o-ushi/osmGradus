import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import '../models/long_article_word_selection_mode.dart';
import '../models/vocabulary_level.dart';
import '../services/vocabulary_service.dart';
import '../theme/app_colors.dart';
import '../utils/japanese_text_chunks.dart';

/// タップした単語（[splitJapaneseIntoChunks]の1チャンク。漢字・カタカナの
/// 連続はまとめて1語）を、確認ダイアログなしで即座に単語帳へ登録する
/// テキスト。登録済みの語は太字＋背景色でハイライトする（選択方式に応じた
/// 単位で照合するため、文字単位で選んだ部分語もハイライトし、本文中の全出現
/// 箇所を対象にする）。
///
/// - **タップ**: その場の1チャンクを確認なしで即座に登録する（常に
///   チャンク単位。1文字だけ即時登録しても大抵は意味を成さないため）。
/// - **長押し＋ドラッグ**: 長押しした位置を起点に、指を動かした分だけ
///   選択範囲を広げ、離すとその範囲をまとめて1語として登録する
///   （確認ダイアログは出さない）。ヒットテストの単位は
///   [AppSettings.longArticleWordSelectionMode]で切り替えられる:
///   [LongArticleWordSelectionMode.character]（既定）は1文字ずつ
///   （漢字・カタカナも連続マージしない）で、長押し直後の微小な指のブレで
///   選択が広がらないよう[dragMoveDeadZone]を設ける（Galaxy S24等の座標
///   ノイズ対策）。[LongArticleWordSelectionMode.chunk]は漢字・カタカナの
///   連続をまとめた単語単位（旧方式）で長押しした瞬間にまとめて選ばれる。
/// - **登録済みの範囲を長押し**: このウィジェット表示中に登録した語の上で
///   長押しすると（ドラッグ不要）、その場で登録を取り消す。表示前から
///   単語帳にあった語（既存エントリ）は対象外——誤って既存データを
///   削除しないため、このウィジェットが登録したエントリだけを対象にする。
class TappableJapaneseText extends StatefulWidget {
  const TappableJapaneseText({
    super.key,
    required this.text,
    required this.onWordRegistered,
    this.onWordUnregistered,
    this.bodyKey = const ValueKey('tappableJapaneseText'),
  });

  final String text;

  /// 単語帳へ新規登録した[VocabularyEntry.id]を通知する。
  final ValueChanged<String> onWordRegistered;

  /// 長押しで登録を取り消した[VocabularyEntry.id]を通知する。
  final ValueChanged<String>? onWordUnregistered;

  /// 本文[Text.rich]に付けるキー。
  final Key bodyKey;

  @override
  State<TappableJapaneseText> createState() => TappableJapaneseTextState();
}

class TappableJapaneseTextState extends State<TappableJapaneseText> {
  final _vocabularyService = VocabularyService();
  final GlobalKey _paragraphKey = GlobalKey();

  /// 既登録語ハイライト・タップ登録・選択範囲確定時の文字列結合に使う
  /// チャンク単位（漢字・カタカナの連続はまとまる）。
  late final List<String> _chunks = splitJapaneseIntoChunks(widget.text);

  /// 長押しドラッグのヒットテスト・既登録語ハイライト用の1文字単位
  /// （[LongArticleWordSelectionMode.character]のときの[_hitUnits]）。
  late final List<String> _charUnits = splitJapaneseIntoCharacters(widget.text);

  /// [AppSettings.longArticleWordSelectionMode]に応じた、長押しドラッグの
  /// ヒットテストと描画分割に使う単位（[_anchorIndex]・[_hoverIndex]・
  /// 既登録語ハイライトは、この配列へのインデックス）。
  List<String> get _hitUnits =>
      appSettings.longArticleWordSelectionMode ==
          LongArticleWordSelectionMode.chunk
      ? _chunks
      : _charUnits;

  Set<String> _registeredWords = {};

  /// このウィジェット表示中に登録した語（word→登録エントリID）。
  /// 長押しでの登録キャンセルはこの語だけを対象にする。
  final Map<String, String> _sessionRegisteredIds = {};
  bool _loadingVocabulary = true;

  /// 長押し＋ドラッグ中の選択範囲（[_hitUnits]へのインデックス）。
  int? _anchorIndex;
  int? _hoverIndex;
  bool _longPressActive = false;

  /// 長押し開始位置が既登録範囲だった場合の対象語（ドラッグでは変わらない。
  /// 離した時点でこの語をそのままキャンセルする）。
  String? _cancelTargetWord;

  /// 長押しを開始したグローバル座標。ドラッグ中の縦方向の微小なブレによる
  /// 意図しない複数行選択を抑制するため、[chunkIndexAtGlobal]の判定基準
  /// として使う。
  Offset? _anchorGlobalPosition;

  /// [chunkIndexAtGlobal]に渡す縦方向の遊びの量。Androidでは
  /// Galaxy S24等での複数行暴発選択を抑えるため、iOS/既定より広い
  /// [dragVerticalJitterToleranceAndroid]を使う。
  static final double _verticalJitterTolerance = Platform.isAndroid
      ? dragVerticalJitterToleranceAndroid
      : dragVerticalJitterTolerance;

  @override
  void initState() {
    super.initState();
    unawaited(reloadRegisteredWords());
  }

  /// 単語帳の内容を再読み込みし、ハイライトとセッション登録を同期する。
  /// 単語帳シートなどでエントリが削除・編集されたあとに呼ぶ。
  Future<void> reloadRegisteredWords() async {
    final entries = await _vocabularyService.loadEntries();
    if (!mounted) return;
    final words = {for (final entry in entries) entry.word};
    final removedSessionIds = <String>[
      for (final entry in _sessionRegisteredIds.entries)
        if (!words.contains(entry.key)) entry.value,
    ];
    setState(() {
      _registeredWords = words;
      _sessionRegisteredIds.removeWhere((word, _) => !words.contains(word));
      _loadingVocabulary = false;
    });
    for (final id in removedSessionIds) {
      widget.onWordUnregistered?.call(id);
    }
  }

  void _onTapUp(TapUpDetails details) {
    final index = chunkIndexAtGlobal(
      textKey: _paragraphKey,
      chunks: _chunks,
      globalPosition: details.globalPosition,
    );
    if (index == null) return;
    unawaited(_registerWord(_chunks[index]));
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final hitIndex = chunkIndexAtGlobal(
      textKey: _paragraphKey,
      chunks: _hitUnits,
      globalPosition: details.globalPosition,
    );
    if (hitIndex == null) return;
    _longPressActive = true;
    final existingWord = _sessionWordAtHitUnitIndex(hitIndex);
    if (existingWord != null) {
      // 既登録範囲の長押し＝キャンセル操作。ドラッグでは範囲を変えない。
      setState(() {
        _cancelTargetWord = existingWord;
        _anchorIndex = null;
        _hoverIndex = null;
      });
      return;
    }
    _anchorGlobalPosition = details.globalPosition;
    setState(() {
      _cancelTargetWord = null;
      _anchorIndex = hitIndex;
      _hoverIndex = hitIndex;
    });
  }

  /// [globalPosition]を選択範囲の[_hitUnits]indexへ解決する。
  /// [LongArticleWordSelectionMode.character]では、長押し開始位置
  /// ([_anchorGlobalPosition])からの直線距離が[dragMoveDeadZone]未満なら、
  /// まだ意図的なドラッグとはみなさずアンカーの文字のまま返す
  /// （指の微小なブレによる1→2文字への意図しない拡大を防ぐ）。
  /// [LongArticleWordSelectionMode.chunk]では、チャンク自体が文字単位より
  /// 粗くこの対策が不要なため、デッドゾーンなしで判定する。
  int? _resolveDraggedIndex(Offset globalPosition) {
    final anchorGlobal = _anchorGlobalPosition;
    final usesDeadZone =
        appSettings.longArticleWordSelectionMode ==
        LongArticleWordSelectionMode.character;
    if (usesDeadZone &&
        anchorGlobal != null &&
        (globalPosition - anchorGlobal).distance < dragMoveDeadZone) {
      return _anchorIndex;
    }
    return chunkIndexAtGlobal(
      textKey: _paragraphKey,
      chunks: _hitUnits,
      globalPosition: globalPosition,
      anchorGlobalPosition: anchorGlobal,
      verticalJitterTolerance: _verticalJitterTolerance,
    );
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_longPressActive || _cancelTargetWord != null) return;
    if (_anchorIndex == null) return;
    final index = _resolveDraggedIndex(details.globalPosition);
    if (index != null && index != _hoverIndex) {
      setState(() => _hoverIndex = index);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_longPressActive) return;
    _longPressActive = false;
    final cancelWord = _cancelTargetWord;
    if (cancelWord != null) {
      setState(() => _cancelTargetWord = null);
      unawaited(_unregisterWord(cancelWord));
      return;
    }
    final index = _resolveDraggedIndex(details.globalPosition);
    if (index != null) {
      setState(() => _hoverIndex = index);
    }
    _anchorGlobalPosition = null;
    _commitSelection();
  }

  void _onLongPressCancel() {
    if (!_longPressActive) return;
    _longPressActive = false;
    _anchorGlobalPosition = null;
    setState(() {
      _cancelTargetWord = null;
      _anchorIndex = null;
      _hoverIndex = null;
    });
  }

  /// ドラッグで広げた選択範囲（[_anchorIndex]〜[_hoverIndex]、[_hitUnits]
  /// へのインデックス）を1語としてまとめて登録する。
  void _commitSelection() {
    final anchor = _anchorIndex;
    final hover = _hoverIndex ?? anchor;
    setState(() {
      _anchorIndex = null;
      _hoverIndex = null;
    });
    if (anchor == null || hover == null) return;
    final start = anchor < hover ? anchor : hover;
    final end = anchor < hover ? hover : anchor;
    unawaited(_registerWord(_hitUnits.sublist(start, end + 1).join()));
  }

  /// 既に単語帳にある語は登録し直さない（同じ語を複数回タップ/選択しても
  /// 重複エントリを作らない）。
  Future<void> _registerWord(String rawSelection) async {
    final word = rawSelection.trim();
    if (word.isEmpty || _registeredWords.contains(word)) return;
    final updated = await _vocabularyService.addEntry(
      word,
      '',
      level: VocabularyLevel.other,
    );
    if (!mounted) return;
    final id = updated.first.id;
    setState(() {
      _registeredWords = {..._registeredWords, word};
      _sessionRegisteredIds[word] = id;
    });
    widget.onWordRegistered(id);
  }

  /// このウィジェット表示中に登録した語（[_sessionRegisteredIds]）だけを
  /// 対象に、単語帳への登録を取り消す。表示前から単語帳にあった語
  /// （既存エントリ）は対象外。
  Future<void> _unregisterWord(String word) async {
    final id = _sessionRegisteredIds[word];
    if (id == null) return;
    await _vocabularyService.deleteEntry(id);
    if (!mounted) return;
    setState(() {
      _registeredWords = {..._registeredWords}..remove(word);
      _sessionRegisteredIds.remove(word);
    });
    widget.onWordUnregistered?.call(id);
  }

  /// [index]（[_hitUnits]へのインデックス）が、このウィジェット表示中に
  /// 登録した語のどれかに含まれていれば、その語を返す（同じ語が本文中に
  /// 複数回出現する場合も対応）。文字単位モードで1文字だけ登録した語も
  /// 対象になる。
  String? _sessionWordAtHitUnitIndex(int index) =>
      _wordAtHitUnitIndex(index, _sessionRegisteredIds.keys);

  String? _wordAtHitUnitIndex(int index, Iterable<String> words) {
    final units = _hitUnits;
    for (final word in words) {
      for (var start = 0; start < units.length; start++) {
        final buffer = StringBuffer();
        for (var end = start; end < units.length; end++) {
          buffer.write(units[end]);
          final joined = buffer.toString();
          if (joined == word) {
            if (index >= start && index <= end) return word;
            break;
          }
          if (joined.length >= word.length) break;
        }
      }
    }
    return null;
  }

  /// [_registeredWords]が[_hitUnits]のどのインデックスに該当するかをまとめて
  /// 求める（既登録語ハイライト用）。文字単位モードではチャンク境界に揃って
  /// いない語（例: 「友」だけ）もハイライトでき、チャンク単位モードでは
  /// [_hitUnits]が[_chunks]そのものなので従来どおり。本文中に同じ語が複数回
  /// 現れる場合は、その全ての出現箇所を対象にする。
  Set<int> _registeredHitUnitIndices() {
    final units = _hitUnits;
    final indices = <int>{};
    for (final rawWord in _registeredWords) {
      final word = rawWord.trim();
      if (word.isEmpty) continue;
      for (var start = 0; start < units.length; start++) {
        final buffer = StringBuffer();
        for (var end = start; end < units.length; end++) {
          buffer.write(units[end]);
          final joined = buffer.toString();
          if (joined == word) {
            for (var k = start; k <= end; k++) {
              indices.add(k);
            }
            break;
          }
          if (joined.length >= word.length) break;
        }
      }
    }
    return indices;
  }

  /// [_hitUnits]へのインデックス（[index]）が現在の選択範囲に入っているか。
  bool _isHitUnitInDraftSelection(int index) {
    final anchor = _anchorIndex;
    if (anchor == null) return false;
    final hover = _hoverIndex ?? anchor;
    final start = anchor < hover ? anchor : hover;
    final end = anchor < hover ? hover : anchor;
    return index >= start && index <= end;
  }

  /// 描画・既登録語ハイライトとも[_hitUnits]（現在の
  /// [LongArticleWordSelectionMode]に応じた単位）で行う。
  List<TextSpan> _buildSpans(AppPalette palette) {
    final units = _hitUnits;
    final registeredIndices = _registeredHitUnitIndices();
    return [
      for (var i = 0; i < units.length; i++)
        TextSpan(
          text: units[i],
          style: TextStyle(
            fontSize: 16,
            height: 1.9,
            color: palette.textOnCardPrimary,
            fontWeight: registeredIndices.contains(i)
                ? FontWeight.bold
                : FontWeight.normal,
            backgroundColor: _isHitUnitInDraftSelection(i)
                ? palette.accentColor.withValues(alpha: 0.35)
                : (registeredIndices.contains(i)
                      ? palette.cardAccent.withValues(alpha: 0.35)
                      : null),
          ),
        ),
    ];
  }

  /// 長押し＋ドラッグでの範囲選択を直接確定する（テスト用。実際の
  /// ジェスチャーは経由しない。osmCogitoの`CogitoWordSelectableTextState`の
  /// `debugSelectRange`と同じ位置付け）。[start]・[end]は現在の
  /// [AppSettings.longArticleWordSelectionMode]に応じた[_hitUnits]への
  /// インデックス。
  @visibleForTesting
  void debugSelectRange(int start, int end) {
    setState(() {
      _anchorIndex = start;
      _hoverIndex = end;
    });
    _commitSelection();
  }

  /// 分割結果のチャンク一覧（テスト用）。
  @visibleForTesting
  List<String> get debugChunks => _chunks;

  /// 現在の[_hitUnits]（テスト用。[AppSettings.longArticleWordSelectionMode]
  /// に応じて[debugChunks]または1文字ずつの分割になる）。
  @visibleForTesting
  List<String> get debugHitUnits => _hitUnits;

  /// 既登録語ハイライト対象の[_hitUnits]インデックス（テスト用）。
  @visibleForTesting
  Set<int> get debugRegisteredHitUnitIndices => _registeredHitUnitIndices();

  @override
  Widget build(BuildContext context) {
    if (_loadingVocabulary) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final palette = AppColors.current;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _onTapUp,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: KeyedSubtree(
        key: widget.bodyKey,
        child: Text.rich(
          key: _paragraphKey,
          TextSpan(children: _buildSpans(palette)),
        ),
      ),
    );
  }
}
