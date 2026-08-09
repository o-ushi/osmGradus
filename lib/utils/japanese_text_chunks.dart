import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum JapaneseCharClass { kanji, hiragana, katakana, other }

JapaneseCharClass classifyJapaneseChar(int codeUnit) {
  if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) return JapaneseCharClass.kanji;
  if (codeUnit >= 0x3040 && codeUnit <= 0x309F) {
    return JapaneseCharClass.hiragana;
  }
  if (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) {
    return JapaneseCharClass.katakana;
  }
  return JapaneseCharClass.other;
}

/// 文字種に応じた簡易分割（辞書は使わない、osmCogitoの
/// `splitCogitoJapaneseIntoChunks`と同じ方式）。
///
/// - 漢字・カタカナの連続はひとまとまり
/// - ひらがな・句読点・空白・数字・英字等は1文字ずつ
///
/// 長文読解のタップ登録（[TappableJapaneseText]）が、タップ位置を「その場で
/// 単語帳へ登録する単位」として使う。
List<String> splitJapaneseIntoChunks(String text) {
  if (text.isEmpty) return const [];
  final chunks = <String>[];
  final buffer = StringBuffer();
  JapaneseCharClass? runClass;

  void flush() {
    if (buffer.isEmpty) return;
    chunks.add(buffer.toString());
    buffer.clear();
    runClass = null;
  }

  for (var i = 0; i < text.length; i++) {
    final charClass = classifyJapaneseChar(text.codeUnitAt(i));
    final ch = text[i];
    final merges =
        charClass == JapaneseCharClass.kanji ||
        charClass == JapaneseCharClass.katakana;
    if (merges && runClass == charClass) {
      buffer.write(ch);
    } else {
      flush();
      buffer.write(ch);
      runClass = merges ? charClass : null;
      if (!merges) flush();
    }
  }
  flush();
  return chunks;
}

/// [splitJapaneseIntoChunks]と違い、漢字・カタカナの連続も一切マージしない、
/// 1コードユニット=1要素の分割（osmCogitoの`splitCogitoJapaneseIntoCharacters`
/// を移植）。既登録語ハイライト・タップ登録には使わず、長押しドラッグの
/// ヒットテストと選択ハイライトの単位専用
/// （[LongArticleWordSelectionMode.character]、S24等での誤選択対策）。
List<String> splitJapaneseIntoCharacters(String text) => [
  for (var i = 0; i < text.length; i++) text[i],
];

/// 長押し認識直後、指の微小な水平方向のブレだけでは選択範囲を広げないための
/// 「移動デッドゾーン」（論理ピクセル、長押し開始位置からの直線距離）。
/// 文字単位のヒットテストは1文字あたりの当たり判定幅が漢字の連続チャンクより
/// 狭くなるため、座標ノイズがそのまま「1文字→隣接文字」への意図しない範囲
/// 拡大として現れやすい。半文字幅程度に設定し、明確な指の移動だけをドラッグ
/// 操作とみなす（osmCogitoの`cogitoDragMoveDeadZone`を移植）。
const double dragMoveDeadZone = 8;

/// ドラッグ中、指の縦方向の微小なブレだけでは行をまたがないようにする
/// 「遊び」の大きさ（論理ピクセル）。[TappableJapaneseText]本文のフォント
/// 設定（fontSize16×height1.9）から求めた1行の高さのおよそ半分
/// （osmCogitoの`cogitoDragVerticalJitterTolerance`を移植）。
const double dragVerticalJitterTolerance = (16 * 1.9) / 2;

/// Android向けの広い「遊び」。Galaxy S24のような高精細・高サンプリングレート
/// のタッチパネルでは、[dragVerticalJitterTolerance]（半行分）でも座標ノイズが
/// それを上回り、複数行が暴発選択されることがあるため、Androidだけ丸々1行分
/// に広げる（osmCogitoの`cogitoDragVerticalJitterToleranceAndroid`を移植）。
const double dragVerticalJitterToleranceAndroid = 16 * 1.9;

/// UTF-16オフセットからチャンクindexを求める。
int chunkIndexForOffset(List<String> chunks, int offset) {
  if (chunks.isEmpty) return 0;
  if (offset <= 0) return 0;
  var cursor = 0;
  for (var i = 0; i < chunks.length; i++) {
    cursor += chunks[i].length;
    if (offset < cursor) return i;
  }
  return chunks.length - 1;
}

/// [RenderParagraph]上のグローバル座標からチャンクindexを求める。
/// 段落の外でも、最も近い位置へクランプする。
///
/// [anchorGlobalPosition]を渡すと（長押し開始位置など）、[globalPosition]の
/// 縦方向のズレが[verticalJitterTolerance]未満のときは開始位置と同じ縦位置と
/// みなして判定する（指の微小なブレによる意図しない複数行選択の抑制）。
int? chunkIndexAtGlobal({
  required GlobalKey textKey,
  required List<String> chunks,
  required Offset globalPosition,
  Offset? anchorGlobalPosition,
  double verticalJitterTolerance = dragVerticalJitterTolerance,
}) {
  if (chunks.isEmpty) return null;
  final ro = textKey.currentContext?.findRenderObject();
  if (ro is! RenderParagraph) return null;
  var local = ro.globalToLocal(globalPosition);
  if (anchorGlobalPosition != null) {
    final anchorLocal = ro.globalToLocal(anchorGlobalPosition);
    if ((local.dy - anchorLocal.dy).abs() < verticalJitterTolerance) {
      local = Offset(local.dx, anchorLocal.dy);
    }
  }
  final clamped = Offset(
    local.dx.clamp(0.0, ro.size.width),
    local.dy.clamp(0.0, ro.size.height),
  );
  final pos = ro.getPositionForOffset(clamped);
  return chunkIndexForOffset(chunks, pos.offset);
}
