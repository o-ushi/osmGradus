import '../data/jlpt_vocabulary_bank.dart';
import '../models/jlpt_vocab_word.dart';
import '../models/vocabulary_entry.dart';
import '../models/vocabulary_level.dart';
import 'vocabulary_service.dart';

/// レイヤーⅠ「語彙を増やす」向けの語彙サービス。
///
/// - **標準語彙（デフォルト）**: [JlptVocabularyBank]（N1/N2/N3各20語）。
///   単語帳ストアには書き込まず、設定ONのとき試験プール／単語帳表示に
///   仮想エントリとしてマージする（＋ボタンとは無関係）。
/// - **ユーザー語彙**: [VocabularyService]（手動追加・Chrome AI取り込み）。
///
/// 重複は単語表記（[VocabularyEntry.word]）単位。ユーザー側が勝つ。
class JlptVocabBankService {
  static const builtinIdPrefix = 'builtin:';

  static String _dedupeKey(String word, String translation) =>
      '$word\u0000$translation';

  /// 標準語彙エントリの安定ID。ストアには保存しない。
  static String builtinId(VocabularyLevel level, String word) =>
      '$builtinIdPrefix${level.storageKey}:$word';

  static bool isBuiltinId(String id) => id.startsWith(builtinIdPrefix);

  static VocabularyEntry entryFromBuiltin(JlptVocabWord word) =>
      VocabularyEntry(
        id: builtinId(word.level, word.word),
        word: word.word,
        reading: word.reading,
        exampleSentence: word.exampleSentence,
        translation: word.translation,
        translationLang: word.translationLang,
        level: word.level,
        // 表示・比較用の固定日時（永続化しない仮想エントリ）。
        createdAt: DateTime.utc(2020, 1, 1),
      );

  static List<VocabularyEntry> allDefaultEntries() => [
    for (final word in JlptVocabularyBank.all) entryFromBuiltin(word),
  ];

  static List<VocabularyEntry> defaultEntriesForLevel(VocabularyLevel level) =>
      [
        for (final word in JlptVocabularyBank.byLevel(level))
          entryFromBuiltin(word),
      ];

  /// [userEntries]に標準語彙をマージする。同じ[VocabularyEntry.word]は
  /// ユーザー側を残す。[level]が非nullならそのレベルだけに絞る。
  static List<VocabularyEntry> mergeWithDefaults(
    List<VocabularyEntry> userEntries, {
    required bool includeDefaults,
    VocabularyLevel? level,
    Set<String> hiddenBuiltinIds = const {},
  }) {
    final filteredUser = level == null
        ? List<VocabularyEntry>.of(userEntries)
        : userEntries.where((entry) => entry.level == level).toList();
    if (!includeDefaults) return filteredUser;

    final defaults = level == null
        ? allDefaultEntries()
        : defaultEntriesForLevel(level);
    final seenWords = {for (final entry in filteredUser) entry.word};
    return [
      ...filteredUser,
      ...defaults.where(
        (entry) =>
            !hiddenBuiltinIds.contains(entry.id) &&
            !seenWords.contains(entry.word),
      ),
    ];
  }

  /// 単語テスト用プール。
  /// [levels]がnullなら（＝「ランダム」）ユーザー語彙・標準語彙とも全レベルを
  /// 対象にする。[levels]を指定した場合はそのレベルの語だけに絞る
  /// （ユーザーが自分で追加した「その他」（[VocabularyLevel.other]）も、
  /// 選ばせる側でチェックボックスの1つとして明示的に選ばれない限り含まない）。
  Future<List<VocabularyEntry>> loadExamPool({
    Set<VocabularyLevel>? levels,
    required bool includeDefaults,
  }) async {
    final vocabularyService = VocabularyService();
    final all = await vocabularyService.loadEntries();
    final hiddenBuiltinIds = await vocabularyService.loadHiddenBuiltinIds();
    final levelFiltered = levels == null
        ? all
        : all.where((entry) => levels.contains(entry.level)).toList();
    // 同じ単語表記が複数エントリ（重複登録・訳語違いの取り込み等）で
    // 単語帳に存在していても、1回のテスト内で同じ単語が2回出題されない
    // よう、単語単位で重複除去する（先頭＝最新のものを残す）。
    final userEntries = <VocabularyEntry>[];
    final seenUserWords = <String>{};
    for (final entry in levelFiltered) {
      if (seenUserWords.add(entry.word)) userEntries.add(entry);
    }
    if (!includeDefaults) return userEntries;

    final defaults = levels == null
        ? allDefaultEntries()
        : [for (final level in levels) ...defaultEntriesForLevel(level)];
    return [
      ...userEntries,
      ...defaults.where(
        (entry) =>
            !hiddenBuiltinIds.contains(entry.id) &&
            !seenUserWords.contains(entry.word),
      ),
    ];
  }

  /// Chrome AIなどで生成した語彙リストを単語帳へ取り込む。
  /// 単語＋訳が既に単語帳にある場合はスキップし、レベルごとの追加件数を返す。
  Future<Map<VocabularyLevel, int>> importWords(
    List<JlptVocabWord> words,
  ) async {
    final added = {
      VocabularyLevel.n1: 0,
      VocabularyLevel.n2: 0,
      VocabularyLevel.n3: 0,
    };
    if (words.isEmpty) return added;

    final vocabularyService = VocabularyService();
    final existingEntries = await vocabularyService.loadEntries();
    final existingKeys = {
      for (final entry in existingEntries)
        _dedupeKey(entry.word, entry.translation),
    };

    for (final word in words) {
      if (word.level == VocabularyLevel.other) continue;
      final key = _dedupeKey(word.word, word.translation);
      if (existingKeys.contains(key)) continue;
      existingKeys.add(key);
      await vocabularyService.addEntry(
        word.word,
        word.translation,
        reading: word.reading,
        exampleSentence: word.exampleSentence,
        translationLang: word.translationLang,
        level: word.level,
      );
      added[word.level] = (added[word.level] ?? 0) + 1;
    }
    return added;
  }
}
