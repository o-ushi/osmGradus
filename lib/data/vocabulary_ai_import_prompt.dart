import '../models/vocabulary_level.dart';
import 'google_ai_search.dart';

/// レイヤーⅠ「語彙を増やす」の Chrome AI 語彙自動生成プロンプト。
/// [PronunciationExerciseAiPrompt]（レイヤーⅤ）と同じく、固定件数の
/// JSON配列を生成させ、[GoogleAiSearch]経由でAIモード検索を開く。
/// 生成対象レベル（N1/N2/N3）はチェックボックスで選べるため、プロンプト・
/// 検索URLとも選択済みレベルの集合を受け取って組み立てる。
abstract final class VocabularyAiImportPrompt {
  VocabularyAiImportPrompt._();

  /// レベルごとに生成させる語数。
  static const int wordsPerLevel = 20;

  static const _levelOrder = [
    VocabularyLevel.n1,
    VocabularyLevel.n2,
    VocabularyLevel.n3,
  ];

  static String _levelName(VocabularyLevel level) => switch (level) {
    VocabularyLevel.n1 => 'N1',
    VocabularyLevel.n2 => 'N2',
    VocabularyLevel.n3 => 'N3',
    VocabularyLevel.other => '',
  };

  /// [levels]で選ばれたレベルだけを、それぞれ[wordsPerLevel]語ずつ
  /// 生成させるプロンプトを組み立てる。
  static String buildBatchPrompt(Set<VocabularyLevel> levels) {
    final selected = [
      for (final level in _levelOrder)
        if (levels.contains(level)) level,
    ];
    final levelNames = selected.map(_levelName).join(' / ');
    final levelKeys = selected.map((l) => l.storageKey).join(' / ');
    final total = selected.length * wordsPerLevel;
    final firstKey = selected.isEmpty ? 'n1' : selected.first.storageKey;

    return 'あなたはJLPT語彙学習用の単語リストを作成するアシスタントです。\n'
        '$levelNames の各レベルについて、それぞれ$wordsPerLevel語（合計$total語）作成してください。\n'
        '\n'
        '【作成ルール】\n'
        '- JLPT各級で実際に出やすい、実用的な語彙にする\n'
        '- wordは日本語表記（漢字かな混じり可）\n'
        '- readingはひらがなのみ（漢字を含まない語はwordと同じでよい）\n'
        '- exampleSentenceはその単語を使った短い日本語の例文\n'
        '- translationはベトナム語の訳\n'
        '- translationLangは常に "vi"\n'
        '- 同じ語をレベル間・レベル内で重複させない\n'
        '\n'
        '【出力形式（このJSON配列のみで回答し、前後に説明文を付けないでください）】\n'
        '[\n'
        '  {"level": "$firstKey", "word": "（日本語）", '
        '"reading": "（ひらがな）", '
        '"exampleSentence": "（例文）", '
        '"translation": "（ベトナム語訳）", '
        '"translationLang": "vi"},\n'
        '  ...（$levelKeysそれぞれ$wordsPerLevel件ずつ、合計$total件）\n'
        ']\n'
        '\n'
        'levelの値は必ず $levelKeys のいずれかにしてください。';
  }

  static Uri buildSearchUrl(Set<VocabularyLevel> levels) =>
      GoogleAiSearch.buildUrl(
        GoogleAiSearch.withJapanesePrefix(buildBatchPrompt(levels)),
      );
}
