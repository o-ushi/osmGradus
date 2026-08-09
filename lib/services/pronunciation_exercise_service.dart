import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/vietnamese_pronunciation_bank.dart';
import '../models/pronunciation_exercise.dart';
import '../models/pronunciation_practice_session.dart';

/// カテゴリごとに課題を抽選し[PronunciationPracticeSession]を組み立てるほか、
/// Chrome AIで生成した発音課題（[PronunciationExerciseSource.imported]）を
/// SharedPreferencesへ保存・読み込み・カテゴリ別削除する。
///
/// 組み込み25問（[VietnamesePronunciationBank]）はコード内に定数として
/// 持つのみで、このクラスの削除系メソッドはSharedPreferences上の
/// 取り込み済み課題にしか作用しない。そのため組み込み課題が削除されることはない。
class PronunciationExerciseService {
  const PronunciationExerciseService();

  static const int questionsPerCategory = 2;
  static const _importedKeyPrefix = 'pronunciation.imported.';

  /// [pool]（省略時は組み込み25文）から各カテゴリ最大[questionsPerCategory]問を
  /// 重複なく抽選し、カテゴリ順に依存しない順序でセッションを組み立てる。
  ///
  /// カテゴリごとの候補が[questionsPerCategory]未満（プールが25問未満など）でも
  /// 例外を投げず、取れるだけ取る。
  ///
  /// [random]を渡すとテストで決定的な結果を得られる。
  PronunciationPracticeSession buildSession({
    List<PronunciationExercise>? pool,
    Random? random,
  }) {
    final rng = random ?? Random();
    final source = pool ?? VietnamesePronunciationBank.all;

    final byCategory = <PronunciationCategory, List<PronunciationExercise>>{
      for (final category in PronunciationCategory.values) category: [],
    };
    for (final exercise in source) {
      byCategory[exercise.category]!.add(exercise);
    }

    final selected = <PronunciationExercise>[];
    for (final category in PronunciationCategory.values) {
      final candidates = List<PronunciationExercise>.of(byCategory[category]!)
        ..shuffle(rng);
      final takeCount = min(questionsPerCategory, candidates.length);
      selected.addAll(candidates.take(takeCount));
    }

    selected.shuffle(rng);

    return PronunciationPracticeSession(
      questions: [
        for (final exercise in selected)
          PronunciationPracticeQuestion(exercise: exercise),
      ],
    );
  }

  /// 組み込み25問とSharedPreferences上の取り込み済み課題を合わせたプール。
  /// [buildSession]の[pool]にそのまま渡せば、抽選時に組み込み・取り込み済み
  /// 両方の課題が対象になる。
  Future<List<PronunciationExercise>> loadFullPool() async {
    return [...VietnamesePronunciationBank.all, ...await loadAllImported()];
  }

  /// 取り込み済み課題を全カテゴリ分読み込む。新しい順（各カテゴリ内は
  /// 取り込まれた順）。
  Future<List<PronunciationExercise>> loadAllImported() async {
    final result = <PronunciationExercise>[];
    for (final category in PronunciationCategory.values) {
      result.addAll(await loadImported(category));
    }
    return result;
  }

  /// 指定カテゴリの取り込み済み課題を読み込む。1件のJSONが壊れていても
  /// そのエントリだけ読み飛ばし、他の課題は読み込む。
  Future<List<PronunciationExercise>> loadImported(
    PronunciationCategory category,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList('$_importedKeyPrefix${category.storageKey}') ??
        const [];
    final result = <PronunciationExercise>[];
    for (final s in raw) {
      try {
        result.add(
          PronunciationExercise.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// [parsed]をカテゴリごとに振り分けて取り込む。ID・文・読みのいずれかが
  /// 組み込み25問または既存の取り込み済み課題と重複するものは除外する。
  /// 戻り値はカテゴリごとの新規追加件数。
  Future<Map<PronunciationCategory, int>> importExercises(
    List<PronunciationExercise> parsed,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final addedCounts = <PronunciationCategory, int>{};

    final byCategory = <PronunciationCategory, List<PronunciationExercise>>{};
    for (final exercise in parsed) {
      byCategory.putIfAbsent(exercise.category, () => []).add(exercise);
    }

    for (final entry in byCategory.entries) {
      final category = entry.key;
      final existingImported = await loadImported(category);
      final existingBuiltIn = VietnamesePronunciationBank.byCategory(
        category,
      );
      final existing = [...existingBuiltIn, ...existingImported];

      final existingIds = {for (final e in existing) e.id};
      final existingSentences = {for (final e in existing) e.sentence};
      final existingReadings = {for (final e in existing) e.reading};

      final toAdd = <PronunciationExercise>[];
      for (final candidate in entry.value) {
        final isDuplicate =
            existingIds.contains(candidate.id) ||
            existingSentences.contains(candidate.sentence) ||
            existingReadings.contains(candidate.reading);
        if (isDuplicate) continue;
        existingIds.add(candidate.id);
        existingSentences.add(candidate.sentence);
        existingReadings.add(candidate.reading);
        toAdd.add(candidate);
      }

      addedCounts[category] = toAdd.length;
      if (toAdd.isEmpty) continue;

      final merged = [...existingImported, ...toAdd];
      await prefs.setStringList('$_importedKeyPrefix${category.storageKey}', [
        for (final e in merged) jsonEncode(e.toJson()),
      ]);
    }

    return addedCounts;
  }

  /// 指定カテゴリの取り込み済み課題だけを削除する（組み込み25問には作用しない）。
  Future<void> clearImported(PronunciationCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_importedKeyPrefix${category.storageKey}');
  }
}
