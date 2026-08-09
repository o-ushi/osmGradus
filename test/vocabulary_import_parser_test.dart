import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  group('VocabularyImportParser.parse 正常系', () {
    test('妥当な3件のJSON配列をすべて取り込める', () {
      final result = VocabularyImportParser.parse(_validBatch);

      expect(result.words, hasLength(3));
      expect(result.rejectedCount, 0);
      expect(result.isEmpty, isFalse);
      expect(
        result.words.map((e) => e.level).toSet(),
        {VocabularyLevel.n1, VocabularyLevel.n2, VocabularyLevel.n3},
      );
      expect(result.words.first.word, '促進');
      expect(result.words.first.reading, 'そくしん');
      expect(result.words.first.translationLang, 'vi');
    });

    test('Markdownのコードフェンスや前後の説明文があっても抽出できる', () {
      final wrapped = '語彙リストです。\n\n```json\n$_validBatch\n```\n\n以上。';
      final result = VocabularyImportParser.parse(wrapped);

      expect(result.words, hasLength(3));
    });

    test('levelが大文字でも取り込める', () {
      const json =
          '[{"level": "N1", "word": "促進", "reading": "そくしん", "translation": "thúc đẩy"}]';
      final result = VocabularyImportParser.parse(json);

      expect(result.words, hasLength(1));
      expect(result.words.single.level, VocabularyLevel.n1);
    });

    test('translationLangが無い／不正ならviにフォールバック', () {
      const json =
          '[{"level": "n2", "word": "予定", "reading": "よてい", "translation": "kế hoạch", "translationLang": "fr"}]';
      final result = VocabularyImportParser.parse(json);

      expect(result.words.single.translationLang, 'vi');
    });

    test('配列末尾の余計なカンマがあっても解析できる', () {
      const json = '''
[
  {"level": "n3", "word": "便利", "reading": "べんり", "translation": "tiện lợi",},
]''';
      final result = VocabularyImportParser.parse(json);

      expect(result.words, hasLength(1));
    });
  });

  group('VocabularyImportParser.parse 異常系', () {
    test('空文字・JSON以外は空結果', () {
      expect(VocabularyImportParser.parse('').isEmpty, isTrue);
      expect(VocabularyImportParser.parse('hello').isEmpty, isTrue);
    });

    test('level不正・必須欠落はrejectedCountに入る', () {
      const json = '''
[
  {"level": "n9", "word": "無効", "reading": "むこう", "translation": "x"},
  {"level": "n1", "word": "", "reading": "あ", "translation": "x"},
  {"level": "n1", "word": "促進", "reading": "そくしん", "translation": "thúc đẩy"}
]''';
      final result = VocabularyImportParser.parse(json);

      expect(result.words, hasLength(1));
      expect(result.rejectedCount, 2);
    });

    test('バッチ内の同一単語は1件だけ残す', () {
      const json = '''
[
  {"level": "n1", "word": "促進", "reading": "そくしん", "translation": "a"},
  {"level": "n2", "word": "促進", "reading": "そくしん", "translation": "b"}
]''';
      final result = VocabularyImportParser.parse(json);

      expect(result.words, hasLength(1));
      expect(result.rejectedCount, 1);
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
