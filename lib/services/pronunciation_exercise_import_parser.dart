import '../models/pronunciation_exercise.dart';
import 'ai_json_extractor.dart';

/// [PronunciationExerciseImportParser.parse]の結果。
class PronunciationExerciseImportResult {
  const PronunciationExerciseImportResult({
    required this.exercises,
    required this.rejectedCount,
  });

  /// 検証を通過した取り込み候補（カテゴリと対象音の整合性チェック済み、
  /// このバッチ内でのID・文・読みの重複は除去済み）。
  final List<PronunciationExercise> exercises;

  /// JSON配列内にはあったが、必須項目の欠落・カテゴリ不一致・バッチ内重複などで
  /// 除外された件数。
  final int rejectedCount;

  bool get isEmpty => exercises.isEmpty;
}

/// [PronunciationExerciseAiPrompt.batchPrompt]への回答（発音課題25件の
/// JSON配列）を解析し、[PronunciationExercise]のリストへ変換する。
///
/// JSON抽出そのものは[AiJsonExtractor]（Markdownのコードフェンスや前置き・
/// 後書きの説明文を無視して`[...]`を総当たりで探す共通ロジック。
/// [PronunciationAiResponseParser]と同じもの）に委ね、ここでは`category`
/// キーを持つ要素の配列である最初の妥当なJSONを採用する。1件ずつ検証し、
/// 不完全な項目は読み飛ばして有効な項目だけを取り込む。
abstract final class PronunciationExerciseImportParser {
  static PronunciationExerciseImportResult parse(String rawResponse) {
    final decoded = AiJsonExtractor.extractFirst<List<dynamic>>(
      rawResponse.trim(),
      open: '[',
      close: ']',
      accept: (decoded) =>
          decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map &&
          (decoded.first as Map).containsKey('category'),
    );
    if (decoded == null) {
      return const PronunciationExerciseImportResult(
        exercises: [],
        rejectedCount: 0,
      );
    }

    final seenIds = <String>{};
    final seenSentences = <String>{};
    final seenReadings = <String>{};
    final exercises = <PronunciationExercise>[];
    var rejected = 0;

    for (final item in decoded) {
      if (item is! Map) {
        rejected++;
        continue;
      }
      final exercise = _tryBuildExercise(Map<String, dynamic>.from(item));
      if (exercise == null) {
        rejected++;
        continue;
      }
      final isDuplicate =
          !seenIds.add(exercise.id) ||
          !seenSentences.add(exercise.sentence) ||
          !seenReadings.add(exercise.reading);
      if (isDuplicate) {
        rejected++;
        continue;
      }
      exercises.add(exercise);
    }

    return PronunciationExerciseImportResult(
      exercises: exercises,
      rejectedCount: rejected,
    );
  }

  static PronunciationExercise? _tryBuildExercise(Map<String, dynamic> json) {
    final categoryKey = json['category'];
    final sentence = json['sentence'];
    final reading = json['reading'];
    final vietnameseHint = json['vietnameseHint'];
    final evaluationPoint = json['evaluationPoint'];

    if (categoryKey is! String) return null;
    final category = _tryParseCategory(categoryKey);
    if (category == null) return null;

    if (sentence is! String || sentence.trim().isEmpty) return null;
    if (reading is! String || reading.trim().isEmpty) return null;
    if (vietnameseHint is! String || vietnameseHint.trim().isEmpty) {
      return null;
    }
    if (evaluationPoint is! String || evaluationPoint.trim().isEmpty) {
      return null;
    }

    final trimmedSentence = sentence.trim();
    final trimmedReading = reading.trim();

    final targetExpressions = _parseTargetExpressions(
      json['targetExpressions'],
    );
    if (targetExpressions.isEmpty) return null;
    if (!targetExpressions.every(trimmedReading.contains)) return null;

    if (!_matchesCategory(category, trimmedReading)) return null;

    return PronunciationExercise(
      id: _stableImportedId(category, trimmedSentence, trimmedReading),
      category: category,
      sentence: trimmedSentence,
      reading: trimmedReading,
      targetExpressions: targetExpressions,
      vietnameseHint: vietnameseHint.trim(),
      evaluationPoint: evaluationPoint.trim(),
      source: PronunciationExerciseSource.imported,
    );
  }

  static List<String> _parseTargetExpressions(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  /// カテゴリと対象音の整合性検証。カテゴリごとに、その発音を表す仮名が
  /// [reading]に実際に含まれているかを確認する（AIが対象音を含まない文を
  /// 生成してしまった場合に取り込まないため）。
  static bool _matchesCategory(PronunciationCategory category, String reading) {
    return switch (category) {
      PronunciationCategory.tsu => reading.contains('つ'),
      PronunciationCategory.zRow => RegExp('[ざじずぜぞ]').hasMatch(reading),
      PronunciationCategory.rRow => RegExp('[らりるれろ]').hasMatch(reading),
      PronunciationCategory.longVowel => _hasLongVowel(reading),
      PronunciationCategory.sokuon => reading.contains('っ'),
    };
  }

  /// 各ひらがなが属する母音（あ・い・う・え・お行）。長音は「直前の仮名の
  /// 母音行にあたる仮名（またはー）が続く」ことで判定する
  /// （例:「くう」＝「く」(う段)＋「う」、「ばあ」＝「ば」(あ段)＋「あ」）。
  /// 単純な文字の2連続（例:「ああ」「いい」）はこの表で母音自身の行として
  /// 扱われるため、そのままこのロジックで判定できる。
  static const Map<String, String> _hiraganaVowel = {
    'あ': 'あ', 'い': 'い', 'う': 'う', 'え': 'え', 'お': 'お',
    'か': 'あ', 'き': 'い', 'く': 'う', 'け': 'え', 'こ': 'お',
    'が': 'あ', 'ぎ': 'い', 'ぐ': 'う', 'げ': 'え', 'ご': 'お',
    'さ': 'あ', 'し': 'い', 'す': 'う', 'せ': 'え', 'そ': 'お',
    'ざ': 'あ', 'じ': 'い', 'ず': 'う', 'ぜ': 'え', 'ぞ': 'お',
    'た': 'あ', 'ち': 'い', 'つ': 'う', 'て': 'え', 'と': 'お',
    'だ': 'あ', 'ぢ': 'い', 'づ': 'う', 'で': 'え', 'ど': 'お',
    'な': 'あ', 'に': 'い', 'ぬ': 'う', 'ね': 'え', 'の': 'お',
    'は': 'あ', 'ひ': 'い', 'ふ': 'う', 'へ': 'え', 'ほ': 'お',
    'ば': 'あ', 'び': 'い', 'ぶ': 'う', 'べ': 'え', 'ぼ': 'お',
    'ぱ': 'あ', 'ぴ': 'い', 'ぷ': 'う', 'ぺ': 'え', 'ぽ': 'お',
    'ま': 'あ', 'み': 'い', 'む': 'う', 'め': 'え', 'も': 'お',
    'や': 'あ', 'ゆ': 'う', 'よ': 'お',
    'ら': 'あ', 'り': 'い', 'る': 'う', 'れ': 'え', 'ろ': 'お',
    'わ': 'あ', 'を': 'お',
  };

  static bool _hasLongVowel(String reading) {
    if (reading.contains('ー')) return true;
    for (var i = 0; i < reading.length - 1; i++) {
      final vowel = _hiraganaVowel[reading[i]];
      if (vowel != null && reading[i + 1] == vowel) return true;
    }
    return false;
  }

  static PronunciationCategory? _tryParseCategory(String key) {
    for (final category in PronunciationCategory.values) {
      if (category.storageKey == key) return category;
    }
    return null;
  }

  /// 同じ内容（カテゴリ・文・読み）から常に同じIDを生成する
  /// （FNV-1a 32bit）。再取り込み時にも安定し、重複除外の判定にも使える。
  static String _stableImportedId(
    PronunciationCategory category,
    String sentence,
    String reading,
  ) {
    final input = '${category.storageKey}|$sentence|$reading';
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'pron_imported_${category.storageKey}_'
        '${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
