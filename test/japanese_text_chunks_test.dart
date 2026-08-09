import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/utils/japanese_text_chunks.dart';

void main() {
  group('splitJapaneseIntoChunks', () {
    test('漢字の連続はひとまとまりになる', () {
      expect(splitJapaneseIntoChunks('友達'), ['友達']);
    });

    test('カタカナの連続はひとまとまりになる', () {
      expect(splitJapaneseIntoChunks('コーヒー'), ['コーヒー']);
    });

    test('ひらがな・句読点は1文字ずつに分かれる', () {
      expect(splitJapaneseIntoChunks('食べた。'), ['食', 'べ', 'た', '。']);
    });

    test('漢字とひらがなが混在する文を正しく分割する', () {
      expect(
        splitJapaneseIntoChunks('友達と公園へ行った。'),
        ['友達', 'と', '公園', 'へ', '行', 'っ', 'た', '。'],
      );
    });

    test('空文字は空リストを返す', () {
      expect(splitJapaneseIntoChunks(''), isEmpty);
    });
  });

  group('chunkIndexForOffset', () {
    test('チャンク境界のオフセットから正しいindexを求める', () {
      final chunks = ['友達', 'と', '公園'];
      // '友達'(2) + 'と'(1) + '公園'(2) = 5文字。
      expect(chunkIndexForOffset(chunks, 0), 0);
      expect(chunkIndexForOffset(chunks, 1), 0);
      expect(chunkIndexForOffset(chunks, 2), 1);
      expect(chunkIndexForOffset(chunks, 3), 2);
      expect(chunkIndexForOffset(chunks, 4), 2);
    });

    test('末尾を超えるオフセットは最後のチャンクにクランプする', () {
      final chunks = ['友達', 'と'];
      expect(chunkIndexForOffset(chunks, 100), 1);
    });

    test('空リストなら0を返す', () {
      expect(chunkIndexForOffset(const [], 3), 0);
    });
  });
}
