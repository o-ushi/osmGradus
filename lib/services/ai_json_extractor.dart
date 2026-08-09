import 'dart:convert';

/// Chrome AI（Google検索AIモード）の回答からJSON部分を抜き出すための共通ロジック。
///
/// AIの回答にはMarkdownのコードフェンスや前置き・後書きの説明文が付くことが
/// 多いため、テキスト中から`{...}`や`[...]`を総当たりで探し、jsonDecode後に
/// 呼び出し側が求める形（特定のキーを持つ等）に合致する最初のものを採用する。
/// [PronunciationAiResponseParser]（JSONオブジェクト）と
/// [PronunciationExerciseImportParser]（JSON配列）の両方が使う。
abstract final class AiJsonExtractor {
  /// [text]中から[open]/[close]の対応が取れたJSON片を先頭から順に探し、
  /// [sanitizeJsonCandidate]で補正した上でjsonDecodeし、[accept]を満たす
  /// 最初の値を返す。見つからなければnull。
  static T? extractFirst<T>(
    String text, {
    required String open,
    required String close,
    required bool Function(Object decoded) accept,
  }) {
    var searchFrom = 0;
    while (true) {
      final start = text.indexOf(open, searchFrom);
      if (start == -1) return null;
      final end = _findMatchingBracket(text, start, open, close);
      if (end == null) {
        searchFrom = start + 1;
        continue;
      }
      final candidate = text.substring(start, end + 1);
      try {
        final decoded = jsonDecode(sanitizeJsonCandidate(candidate));
        if (decoded != null && accept(decoded as Object)) {
          return decoded as T;
        }
      } catch (_) {
        // このブロックはJSONとして不正だった。次の開き括弧から探す。
      }
      searchFrom = start + 1;
    }
  }

  /// Chrome AIの回答をそのままコピー＆貼り付けすると、JSON文字列リテラルの
  /// 中に生の改行・タブが混ざっていたり（エスケープされていない）、
  /// オブジェクトや配列の末尾に余計なカンマが付いていたり、フィードバック文
  /// 中の`"th"`のような引用語がエスケープされずそのまま紛れ込んでいたりする
  /// （いずれも`jsonDecode`が拒否する、AI出力でよくある崩れ方）。
  /// 文字列リテラルの内と外を区別しながら、これらを`jsonDecode`が
  /// 受け付ける形へ補正する。
  static String sanitizeJsonCandidate(String candidate) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < candidate.length; i++) {
      final ch = candidate[i];
      if (inString) {
        if (escaped) {
          buffer.write(ch);
          escaped = false;
        } else if (ch == r'\') {
          buffer.write(ch);
          escaped = true;
        } else if (ch == '"') {
          if (_looksLikeJsonStringEnd(candidate, i)) {
            inString = false;
            buffer.write(ch);
          } else {
            // 直後がJSONの区切り記号（`:` `,` `}` `]`）ではないため、
            // 文字列の終端ではなく文中に紛れ込んだ引用符とみなし、
            // エスケープして文字列内容として扱う。
            buffer.write(r'\"');
          }
        } else if (ch == '\n') {
          buffer.write(r'\n');
        } else if (ch == '\r') {
          // 直後の\nと重複しないよう、\rだけの行送りは無視する。
        } else if (ch == '\t') {
          buffer.write(r'\t');
        } else {
          buffer.write(ch);
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        buffer.write(ch);
        continue;
      }
      if (ch == ',') {
        var j = i + 1;
        while (j < candidate.length && _isJsonWhitespace(candidate[j])) {
          j++;
        }
        if (j < candidate.length &&
            (candidate[j] == '}' || candidate[j] == ']')) {
          // 閉じ括弧の直前の末尾カンマは書き込まずに読み飛ばす。
          continue;
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  static bool _isJsonWhitespace(String ch) =>
      ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';

  /// [text]内、[quoteIndex]位置の`"`が正当なJSON文字列の終端かどうかを、
  /// 直後（空白を読み飛ばした先）が`:` `,` `}` `]` のいずれか、または
  /// テキスト末尾であるかで判定する。
  ///
  /// Chrome AIの回答は、フィードバック文中で`"th"`や`"ch"`のような
  /// 引用語をエスケープせずそのまま書いてしまうことがある。厳密なJSONでは
  /// 引用符は常に文字列の終端を意味するため、このような文中の引用符を
  /// 「終端ではない」と判定できないと、そこで文字列が途切れたと誤認して
  /// 構文エラーになってしまう。この先読みヒューリスティックで、
  /// 文中の引用符と本当の終端を区別する。
  static bool _looksLikeJsonStringEnd(String text, int quoteIndex) {
    var j = quoteIndex + 1;
    while (j < text.length && _isJsonWhitespace(text[j])) {
      j++;
    }
    if (j >= text.length) return true;
    final next = text[j];
    return next == ':' || next == ',' || next == '}' || next == ']';
  }

  /// [start]位置の[open]に対応する[close]のインデックスを、文字列リテラル内の
  /// 括弧を無視しながら探す。対応が取れなければnull。
  ///
  /// 文字列リテラル内に紛れ込んだエスケープなしの引用符（[_looksLikeJsonStringEnd]
  /// 参照）で誤って文字列の終端と判定し、対応する閉じ括弧を見誤らないよう、
  /// [sanitizeJsonCandidate]と同じヒューリスティックで判定する。
  static int? _findMatchingBracket(
    String text,
    int start,
    String open,
    String close,
  ) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"' && _looksLikeJsonStringEnd(text, i)) {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == open) {
        depth++;
      } else if (ch == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }
}
