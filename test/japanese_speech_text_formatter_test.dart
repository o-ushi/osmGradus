import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/services/japanese_speech_text_formatter.dart';

void main() {
  test('短い文は正規化のみで1塊として返る', () {
    final chunks = JapaneseSpeechTextFormatter.utteranceChunks('こんにちは！元気ですか?');
    expect(chunks, ['こんにちは！元気ですか？']);
  });

  test('改行は句点に変換される', () {
    final chunks = JapaneseSpeechTextFormatter.utteranceChunks(
      'おはよう\nこんにちは\r\nこんばんは',
    );
    expect(chunks, ['おはよう。こんにちは。こんばんは']);
  });

  test('連続する句点は1つにまとめられる', () {
    final chunks = JapaneseSpeechTextFormatter.utteranceChunks('やった。。。すごい。');
    expect(chunks, ['やった。すごい。']);
  });

  test('空文字はチャンクなしになる', () {
    expect(JapaneseSpeechTextFormatter.utteranceChunks(''), isEmpty);
    expect(JapaneseSpeechTextFormatter.utteranceChunks('   '), isEmpty);
  });

  test('400字を超える長文は句点で分割される', () {
    final sentence = 'これはテスト用の文章です。' * 40; // 400字超
    final chunks = JapaneseSpeechTextFormatter.utteranceChunks(sentence);
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(chunk.trim(), isNotEmpty);
    }
    // 分割しても元の文字はすべて保持される。
    expect(chunks.join(''), JapaneseSpeechTextFormatter.normalize(sentence));
  });

  test('句点のない長い読点区切り文は120字を超えたところで分割される', () {
    final segment = 'あ' * 30;
    final sentence = List.filled(20, segment).join('、'); // 句点なし、読点多数
    final chunks = JapaneseSpeechTextFormatter.utteranceChunks(sentence);
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(150));
    }
  });
}
