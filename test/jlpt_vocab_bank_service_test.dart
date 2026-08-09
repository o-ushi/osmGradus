import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/data/jlpt_vocabulary_bank.dart';
import 'package:osm_gradus/models/jlpt_vocab_word.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/services/jlpt_vocab_bank_service.dart';
import 'package:osm_gradus/services/vocabulary_import_parser.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';

const _validBatch = '''
[
  {"level": "n1", "word": "促進", "reading": "そくしん", "translation": "thúc đẩy", "translationLang": "vi"},
  {"level": "n2", "word": "予定", "reading": "よてい", "translation": "kế hoạch", "translationLang": "vi"},
  {"level": "n3", "word": "便利", "reading": "べんり", "translation": "tiện lợi", "translationLang": "vi"}
]''';

void main() {
  group('JlptVocabularyBank 標準データ', () {
    test('各レベル20語以上ある', () {
      for (final level in [
        VocabularyLevel.n1,
        VocabularyLevel.n2,
        VocabularyLevel.n3,
      ]) {
        expect(
          JlptVocabularyBank.byLevel(level).length,
          greaterThanOrEqualTo(20),
          reason: '${level.storageKey}は20語以上必要',
        );
      }
    });

    test('レベル内で単語が重複しない', () {
      for (final level in [
        VocabularyLevel.n1,
        VocabularyLevel.n2,
        VocabularyLevel.n3,
      ]) {
        final words = JlptVocabularyBank.byLevel(level).map((e) => e.word);
        expect(
          words.toSet().length,
          words.length,
          reason: '${level.storageKey}に重複した単語がある',
        );
      }
    });

    test('otherレベルには標準語がない', () {
      expect(JlptVocabularyBank.byLevel(VocabularyLevel.other), isEmpty);
    });

    test('すべての標準語に例文がある', () {
      for (final word in JlptVocabularyBank.all) {
        expect(
          word.exampleSentence.trim(),
          isNotEmpty,
          reason: '${word.word}（${word.level.storageKey}）',
        );
      }
    });
  });

  group('JlptVocabBankService 標準語の仮想マージ', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('includeDefaults=trueなら、空の単語帳でもN1が20語のプールになる', () async {
      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1},
        includeDefaults: true,
      );

      expect(pool, hasLength(20));
      expect(pool.every((e) => JlptVocabBankService.isBuiltinId(e.id)), isTrue);
      expect(pool.every((e) => e.level == VocabularyLevel.n1), isTrue);
      expect(pool.every((e) => e.exampleSentence.isNotEmpty), isTrue);
    });

    test('includeDefaults=falseなら、空の単語帳のプールは空', () async {
      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1},
        includeDefaults: false,
      );

      expect(pool, isEmpty);
    });

    test('ユーザー語と標準語が同じ単語ならユーザー側が勝つ', () async {
      await VocabularyService().addEntry(
        JlptVocabularyBank.byLevel(VocabularyLevel.n1).first.word,
        'user-translation',
        reading: 'user-reading',
        level: VocabularyLevel.n1,
      );

      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1},
        includeDefaults: true,
      );

      expect(pool, hasLength(20));
      final userWord = pool.firstWhere(
        (e) => e.translation == 'user-translation',
      );
      expect(JlptVocabBankService.isBuiltinId(userWord.id), isFalse);
      expect(userWord.reading, 'user-reading');
    });

    test('ランダム相当（levels=null）はN1+N2+N3で60語', () async {
      final pool = await JlptVocabBankService().loadExamPool(
        includeDefaults: true,
      );

      expect(pool, hasLength(60));
      expect(pool.map((e) => e.level).toSet(), {
        VocabularyLevel.n1,
        VocabularyLevel.n2,
        VocabularyLevel.n3,
      });
    });

    test('levelsを指定すると、その他（レベル未指定）の語は明示的に含めない限り除外される', () async {
      await VocabularyService().addEntry('自分の単語', 'my word');

      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1},
        includeDefaults: false,
      );

      expect(pool, isEmpty);
    });

    test('その他をlevelsに含めれば、明示的に選んだ分だけプールに入る', () async {
      await VocabularyService().addEntry('自分の単語', 'my word');

      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1, VocabularyLevel.other},
        includeDefaults: false,
      );

      expect(pool, hasLength(1));
      expect(pool.first.word, '自分の単語');
      expect(pool.first.level, VocabularyLevel.other);
    });

    test('includeDefaults=trueでも、その他を明示的に含めれば標準語に加えて含まれる', () async {
      await VocabularyService().addEntry('自分の単語', 'my word');

      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n2, VocabularyLevel.other},
        includeDefaults: true,
      );

      expect(pool, hasLength(21));
      expect(pool.where((e) => e.level == VocabularyLevel.other), hasLength(1));
    });

    test('ユーザー語彙に同じ単語が複数エントリあっても試験プールでは1つにまとめる', () async {
      await VocabularyService().addEntry(
        '重複語',
        '訳1',
        level: VocabularyLevel.n1,
      );
      await VocabularyService().addEntry(
        '重複語',
        '訳2',
        level: VocabularyLevel.n1,
      );

      final pool = await JlptVocabBankService().loadExamPool(
        levels: {VocabularyLevel.n1},
        includeDefaults: false,
      );

      expect(pool, hasLength(1));
      // 先頭（＝最後に追加＝最新）が残る。
      expect(pool.first.translation, '訳2');
    });

    test('ランダム（levels=null）はその他の語も常に含む', () async {
      await VocabularyService().addEntry('自分の単語', 'my word');

      final pool = await JlptVocabBankService().loadExamPool(
        includeDefaults: false,
      );

      expect(pool, hasLength(1));
      expect(pool.first.level, VocabularyLevel.other);
    });
  });

  group('JlptVocabBankService.importWords', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('パース結果を単語帳にレベル付きで追加できる', () async {
      final parsed = VocabularyImportParser.parse(_validBatch);
      final added = await JlptVocabBankService().importWords(parsed.words);

      expect(added[VocabularyLevel.n1], 1);
      expect(added[VocabularyLevel.n2], 1);
      expect(added[VocabularyLevel.n3], 1);
      final entries = await VocabularyService().loadEntries();
      expect(entries, hasLength(3));
    });

    test('同じ語を再取り込みしても重複しない', () async {
      final service = JlptVocabBankService();
      final words = VocabularyImportParser.parse(_validBatch).words;

      final first = await service.importWords(words);
      final second = await service.importWords(words);

      expect(first.values.fold<int>(0, (a, b) => a + b), 3);
      expect(second.values.fold<int>(0, (a, b) => a + b), 0);
      expect(await VocabularyService().loadEntries(), hasLength(3));
    });

    test('手動登録済みの語（単語＋訳）はスキップする', () async {
      await VocabularyService().addEntry(
        '促進',
        'thúc đẩy',
        reading: 'そくしん',
        level: VocabularyLevel.n1,
      );

      final added = await JlptVocabBankService().importWords([
        const JlptVocabWord(
          level: VocabularyLevel.n1,
          word: '促進',
          reading: 'そくしん',
          translation: 'thúc đẩy',
        ),
        const JlptVocabWord(
          level: VocabularyLevel.n2,
          word: '予定',
          reading: 'よてい',
          translation: 'kế hoạch',
        ),
      ]);

      expect(added[VocabularyLevel.n1], 0);
      expect(added[VocabularyLevel.n2], 1);
    });
  });
}
