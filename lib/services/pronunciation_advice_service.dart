import '../localization/app_strings.dart';
import '../models/pronunciation_evaluation.dart';
import '../models/pronunciation_exercise.dart';

/// Chrome AIの参考評価から、最もスコアが低いカテゴリに絞った改善アドバイスを作る。
class PronunciationAdviceService {
  const PronunciationAdviceService();

  static const Map<PronunciationCategory, String> _displayNames = {
    PronunciationCategory.tsu: 'つ',
    PronunciationCategory.zRow: 'ざ行',
    PronunciationCategory.rRow: 'ら行',
    PronunciationCategory.longVowel: '長音',
    PronunciationCategory.sokuon: '促音',
  };

  /// スコアが最も低いカテゴリから最大[maxCategories]件を選ぶ。
  ///
  /// スコアが同点の場合は[PronunciationCategory]の宣言順（tsu→zRow→rRow→
  /// longVowel→sokuon）をタイブレークに使うため、同じ評価内容なら
  /// [categoryEvaluations]の格納順によらず常に同じ結果になる。
  List<PronunciationCategory> lowestScoringCategories(
    PronunciationEvaluation evaluation, {
    int maxCategories = 2,
  }) {
    final entries = evaluation.categoryEvaluations.entries.toList()
      ..sort((a, b) {
        final scoreCompare = a.value.score.compareTo(b.value.score);
        if (scoreCompare != 0) return scoreCompare;
        return a.key.index.compareTo(b.key.index);
      });
    return entries.take(maxCategories).map((entry) => entry.key).toList();
  }

  /// 最もスコアが低い1〜2カテゴリに言及する改善アドバイス文を作る。
  /// 例: 「あなたは「つ」と「ら行」を練習すると、日本人への伝わり方が大きく改善します。」
  ///
  /// カテゴリ名（つ・ざ行・ら行・長音・促音）は日本語の発音カテゴリ名として
  /// [languageCode]に関わらず日本語表記のまま埋め込むが、文全体は
  /// [languageCode]（省略時は'ja'）に応じて翻訳する。
  String buildAdvice(
    PronunciationEvaluation evaluation, [
    String languageCode = 'ja',
  ]) {
    final categories = lowestScoringCategories(evaluation);
    if (categories.isEmpty) return '';

    final names = categories
        .map((category) => _displayNames[category] ?? category.storageKey)
        .toList();
    final joinedNames = names.length == 1
        ? '「${names[0]}」'
        : '「${names[0]}」と「${names[1]}」';

    return 'あなたは%@を練習すると、日本人への伝わり方が大きく改善します。'.trFmt(languageCode, [
      joinedNames,
    ]);
  }
}
