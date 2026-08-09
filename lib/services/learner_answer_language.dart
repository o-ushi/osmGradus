/// 学習者の回答言語（ベトナム語 / 英語 / 日本語）。
/// 音声・キーボードとも画面の回答言語ボタン（🇻🇳/🇺🇸/🇯🇵）で選ぶ。
enum LearnerAnswerLanguage { vi, en, ja }

/// 回答テキストから言語を推定する（[answerLanguageCode] が無い旧データ向け
/// フォールバックなど）。本番の採点言語は回答言語ボタンの選択を優先する。
///
/// 声調記号のないラテン文字は英語ではなくベトナム語とみなす
/// （主な利用者はベトナム語で答え、IMEなし入力が多いため）。
abstract final class LearnerAnswerLanguageDetector {
  static final RegExp _vietnameseDiacritics = RegExp(
    r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
    r'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]',
  );

  static LearnerAnswerLanguage detect(String? text) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return LearnerAnswerLanguage.vi;
    if (_vietnameseDiacritics.hasMatch(trimmed)) {
      return LearnerAnswerLanguage.vi;
    }

    var hiragana = 0;
    var katakana = 0;
    var kanji = 0;
    var latin = 0;

    for (final character in trimmed.split('')) {
      if (_isIgnorable(character)) continue;
      if (_isHiragana(character)) {
        hiragana++;
        continue;
      }
      if (_isKatakana(character)) {
        katakana++;
        continue;
      }
      if (_isKanji(character)) {
        kanji++;
        continue;
      }
      if (_isBasicLatin(character)) {
        latin++;
      }
    }

    final japanese = hiragana + katakana + kanji;
    final significant = japanese + latin;
    if (significant == 0) return LearnerAnswerLanguage.vi;

    if (japanese / significant >= 0.25) {
      return LearnerAnswerLanguage.ja;
    }
    // 声調なしラテン文字は英語よりベトナム語を優先する。
    if (latin > 0) {
      return LearnerAnswerLanguage.vi;
    }
    return LearnerAnswerLanguage.vi;
  }

  static String detectCode(String? text) => detect(text).code;

  static LearnerAnswerLanguage? fromCode(String? code) => switch (code) {
    'vi' => LearnerAnswerLanguage.vi,
    'en' => LearnerAnswerLanguage.en,
    'ja' => LearnerAnswerLanguage.ja,
    _ => null,
  };

  static bool _isIgnorable(String character) =>
      character.trim().isEmpty || character == '\u3000';

  static bool _isHiragana(String character) {
    if (character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    return code >= 0x3040 && code <= 0x309F;
  }

  static bool _isKatakana(String character) {
    if (character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    return (code >= 0x30A0 && code <= 0x30FF) ||
        (code >= 0xFF66 && code <= 0xFF9D);
  }

  static bool _isKanji(String character) {
    if (character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF);
  }

  static bool _isBasicLatin(String character) {
    if (character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    return (code >= 0x0041 && code <= 0x005A) ||
        (code >= 0x0061 && code <= 0x007A);
  }
}

extension LearnerAnswerLanguageX on LearnerAnswerLanguage {
  String get code => switch (this) {
    LearnerAnswerLanguage.vi => 'vi',
    LearnerAnswerLanguage.en => 'en',
    LearnerAnswerLanguage.ja => 'ja',
  };

  String get flag => switch (this) {
    LearnerAnswerLanguage.vi => '🇻🇳',
    LearnerAnswerLanguage.en => '🇺🇸',
    LearnerAnswerLanguage.ja => '🇯🇵',
  };

  /// [RecordingSttService.stopAndTranscribe]へ渡すBCP-47ロケールタグ。
  String get localeTag => switch (this) {
    LearnerAnswerLanguage.vi => 'vi-VN',
    LearnerAnswerLanguage.en => 'en-US',
    LearnerAnswerLanguage.ja => 'ja-JP',
  };

  LearnerAnswerLanguage get next => switch (this) {
    LearnerAnswerLanguage.vi => LearnerAnswerLanguage.en,
    LearnerAnswerLanguage.en => LearnerAnswerLanguage.ja,
    LearnerAnswerLanguage.ja => LearnerAnswerLanguage.vi,
  };
}
