import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/question_prompt.dart';
import 'question_prompt_service.dart';

/// [QuestionPromptJsonTransfer.importFromContent]の結果。
class QuestionPromptJsonImportResult {
  const QuestionPromptJsonImportResult({
    required this.added,
    required this.skipped,
  });

  final int added;
  final int skipped;
}

/// 起動画面「•••」の「問題のみ」エクスポート／インポート（Step 4後の追加要望）。
///
/// [TopicJsonTransfer]（カテゴリ・本文のみの簡易形式）とは別に、[QuestionPrompt]
/// の全フィールド（理解・要約・PREP・スコア・単語登録参照など）をそのまま
/// 書き出し／読み込みする、問題文単体の構造化JSON形式。[GradusBackup]の
/// フルバックアップが持つ`questionPrompts`節と同じ形（[QuestionPrompt.toJson]
/// そのまま）で互換性を保ち、どちらのファイルもこのクラスで読み込める。
abstract final class QuestionPromptJsonTransfer {
  static const formatVersion = 1;
  static const filePrefix = 'osmGradus_questionPrompts_';

  static Future<int> itemCount() async => (await _backedUpPrompts()).length;

  /// 未使用の組み込み問題文（[QuestionPrompt.hasUserData]がfalse）は
  /// [TopicBank]が既に静的に持つ内容と重複するため対象外とする
  /// （[GradusBackup]のフルバックアップと同じ考え方）。
  static Future<List<QuestionPrompt>> _backedUpPrompts() async {
    final all = await QuestionPromptService().loadAll();
    return all.where((p) => p.hasUserData).toList();
  }

  static Future<String> buildExportJson() async {
    final prompts = await _backedUpPrompts();
    final bundle = {
      'version': formatVersion,
      'questionPrompts': prompts.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  static Future<File> writeExportFile() async {
    final json = await buildExportJson();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .substring(0, 15);
    final file = File('${dir.path}/$filePrefix$stamp.json');
    await file.writeAsString(json, flush: true);
    return file;
  }

  /// `{ "version": 1, "questionPrompts": [ {...QuestionPrompt.toJson()}, ... ] }`
  /// 形式を読み込み、[QuestionPromptService.importPrompts]でIDが重複しない分
  /// だけマージする。壊れたJSON・不正な形はすべて[FormatException]にまとめて
  /// 投げる（呼び出し側でエラーダイアログを出す）。個々の要素の解析失敗は
  /// 例外にせずスキップ件数に含める。
  static Future<QuestionPromptJsonImportResult> importFromContent(
    String raw,
  ) async {
    final content = raw.trim().replaceFirst('﻿', '');
    if (content.isEmpty) {
      throw const FormatException('empty file');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid format');
    }
    final promptsRaw = decoded['questionPrompts'];
    if (promptsRaw is! List) {
      throw const FormatException('missing questionPrompts');
    }

    final parsed = <QuestionPrompt>[];
    var skipped = 0;
    for (final item in promptsRaw) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      try {
        parsed.add(QuestionPrompt.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        skipped++;
      }
    }

    final tally = await QuestionPromptService().importPrompts(parsed);
    return QuestionPromptJsonImportResult(
      added: tally.added,
      skipped: tally.skipped + skipped,
    );
  }
}
