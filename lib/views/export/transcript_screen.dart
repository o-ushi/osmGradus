import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/jsst_reference_samples.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/dashboard_summary.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../models/saved_scoring_result.dart';
import '../../models/saved_vocabulary_check.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/jsst_scoring_service.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../services/scoring_result_storage.dart';
import '../../services/thinking_matrix_service.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// 起動画面の「…」→「成績証明証」から開く、1画面に収まる形の
/// 簡易証明書。発行日時・総合判定・会話/語彙/発音の直近3件と、
/// 発行時点の25マス拡充度を[DashboardSummaryService]と同じ計算でまとめる。
class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TranscriptScreen()));
  }

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  static const _rowsPerCategory = DashboardSummaryService.recentLimit;

  final _issuedAt = DateTime.now();

  bool _loading = true;
  DashboardSummary _summary = const DashboardSummary(
    overallGrade: DashboardOverallGrade.e,
    jsstSampleCount: 0,
    pronunciationSampleCount: 0,
    vocabularySampleCount: 0,
  );
  List<SavedScoringResult> _scoringResults = const [];
  List<SavedPronunciationCheck> _pronunciationChecks = const [];
  List<SavedVocabularyCheck> _vocabularyChecks = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final thinkingMatrixService = ThinkingMatrixService();
    await thinkingMatrixService.ensureSystemPresets();
    final scoring = await ScoringResultStorage().loadAll();
    final pronunciation = await PronunciationCheckStorage().loadAll();
    final vocabulary = await VocabularyCheckStorage().loadAll();
    final thinkingMatrixSets = await thinkingMatrixService.loadAll();
    if (!mounted) return;
    setState(() {
      _scoringResults = scoring.take(_rowsPerCategory).toList();
      _pronunciationChecks = pronunciation.take(_rowsPerCategory).toList();
      _vocabularyChecks = vocabulary.take(_rowsPerCategory).toList();
      _summary = DashboardSummaryService.build(
        scoringResults: scoring,
        pronunciationChecks: pronunciation,
        vocabularyChecks: vocabulary,
        thinkingMatrixSets: thinkingMatrixSets,
      );
      _loading = false;
    });
  }

  /// 直近3件分の行を常に返す。不足分は日付・成績の位置に「ー」を置く。
  List<_CategoryRow> _padRows(List<_CategoryRow> rows) {
    return [
      for (var i = 0; i < _rowsPerCategory; i++)
        i < rows.length ? rows[i] : const _CategoryRow(date: 'ー', result: 'ー'),
    ];
  }

  /// JSST・的中度・PREPは同じレイヤーⅣ結果から同時に得られるため、
  /// 3列（JSST/的中度/PREP）1行にまとめた「会話」表を1件（1日時）分
  /// 返す（[_padRows]と同じく直近3件に満たない分は「ー」で埋める）。
  /// JSST列の値は列見出しに既に「JSST」とあるため、
  /// [JsstReferenceSamples.levelLabel]の「JSST 」接頭辞を外し帯だけにする
  /// （「JSST 7〜」ではなく「7〜」、折り返し防止）。
  List<_ConversationRow> _conversationRows(String lang) {
    final rows = [
      for (final saved in _scoringResults)
        _ConversationRow(
          date: _certificateTimestamp(saved.createdAt, lang),
          jsst: JsstReferenceSamples.levelLabel(
            JsstScoringService.combinedReferenceLevel(saved.result),
          ).replaceFirst('JSST ', ''),
          hit: saved.hasAiEvaluation
              ? saved.hitStars!.toDouble().toStringAsFixed(1)
              : 'ー',
          prep: saved.hasAiEvaluation
              ? saved.prepStars!.toDouble().toStringAsFixed(1)
              : 'ー',
        ),
    ];
    return [
      for (var i = 0; i < _rowsPerCategory; i++)
        i < rows.length
            ? rows[i]
            : const _ConversationRow(
                date: 'ー',
                jsst: 'ー',
                hit: 'ー',
                prep: 'ー',
              ),
    ];
  }

  List<_CategoryRow> _pronunciationRows(String lang) => _padRows([
    for (final check in _pronunciationChecks)
      _CategoryRow(
        date: _certificateTimestamp(check.createdAt, lang),
        result: _pronunciationStars(check) ?? 'ー',
      ),
  ]);

  List<_CategoryRow> _vocabularyRows(String lang) => _padRows([
    for (final check in _vocabularyChecks)
      _CategoryRow(
        date: _certificateTimestamp(check.createdAt, lang),
        result: check.evaluation?.starDisplay ?? 'ー',
      ),
  ]);

  /// [DashboardSummaryService]の平均計算と同じ「5カテゴリの平均→四捨五入」を
  /// 1件分に適用した★表示（そちらは直近3件の平均、こちらは1件ごとの平均）。
  String? _pronunciationStars(SavedPronunciationCheck check) {
    final evaluation = check.evaluation;
    if (evaluation == null || evaluation.categoryEvaluations.isEmpty) {
      return null;
    }
    final scores = evaluation.categoryEvaluations.values.map((e) => e.score);
    final total = scores.fold<int>(0, (sum, score) => sum + score);
    final average = total / evaluation.categoryEvaluations.length;
    final rounded = average.round().clamp(1, 5);
    return '${'★' * rounded}${'☆' * (5 - rounded)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return OsmSubpageScaffold(
      title: Text('成績証明証'.tr(lang)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeaderRow(issuedAt: _issuedAt, lang: lang),
                            const SizedBox(height: 12),
                            _TranscriptGradeTable(
                              summary: _summary,
                              lang: lang,
                            ),
                            const SizedBox(height: 14),
                            _ConversationBlock(
                              color: kLayerColors[3],
                              title: '会話'.tr(lang),
                              rows: _conversationRows(lang),
                            ),
                            const SizedBox(height: 10),
                            _CategoryBlock(
                              section: (
                                color: kLayerColors[0],
                                title: '語彙'.tr(lang),
                                rows: _vocabularyRows(lang),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CategoryBlock(
                              section: (
                                color: kLayerColors[4],
                                title: '発音'.tr(lang),
                                rows: _pronunciationRows(lang),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ExpansionBlock(
                              issuedAt: _issuedAt,
                              summary: _summary,
                              lang: lang,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 証明証の日付（ゼロ埋め。ja/en は月/日、vi は日/月）。
String _certificateDate(DateTime dt, String lang) {
  final y = dt.year;
  final m = _two(dt.month);
  final d = _two(dt.day);
  return switch (lang) {
    'en' => '$m/$d/$y',
    'vi' => '$d/$m/$y',
    _ => '$y/$m/$d',
  };
}

/// 証明証の履歴行日時（ゼロ埋め。年なし）。
String _certificateTimestamp(DateTime dt, String lang) {
  final m = _two(dt.month);
  final d = _two(dt.day);
  final time = '${_two(dt.hour)}:${_two(dt.minute)}';
  final date = switch (lang) {
    'vi' => '$d/$m',
    _ => '$m/$d',
  };
  return '$date $time';
}

/// 1行に収める（英語・ベトナム語の長い見出しが折り返さないように縮小）。
class _NoWrapText extends StatelessWidget {
  const _NoWrapText(
    this.text, {
    required this.style,
    this.align = TextAlign.left,
  });

  final String text;
  final TextStyle style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: switch (align) {
        TextAlign.right => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      },
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: align,
        style: style,
      ),
    );
  }
}

/// アプリアイコン（左）＋発行日・発行時間（右）。判定3行は[_TranscriptGradeTable]。
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.issuedAt, required this.lang});

  final DateTime issuedAt;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final metaStyle = TextStyle(
      fontSize: 13,
      color: palette.textOnSubpageSecondary,
    );
    final metaLabelStyle = metaStyle.copyWith(fontWeight: FontWeight.w600);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoWrapText(
                '${'発行日'.tr(lang)}：${_certificateDate(issuedAt, lang)}',
                style: metaLabelStyle,
              ),
              const SizedBox(height: 2),
              _NoWrapText(
                '${'発行時間'.tr(lang)}：${_two(issuedAt.hour)}:${_two(issuedAt.minute)}',
                style: metaLabelStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 総合判定／テスト総合／拡充度総合。A〜Eの文字を同じ横位置に揃える。
class _TranscriptGradeTable extends StatelessWidget {
  const _TranscriptGradeTable({required this.summary, required this.lang});

  final DashboardSummary summary;
  final String lang;

  static const overallLetterKey = Key('transcript-grade-letter-overall');
  static const testLetterKey = Key('transcript-grade-letter-test');
  static const expansionLetterKey = Key('transcript-grade-letter-expansion');

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final labelStyle = TextStyle(
      fontSize: 13,
      color: palette.textOnSubpageSecondary,
    );
    final letterStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: palette.textOnSubpagePrimary,
      height: 1.1,
    );
    final overallLetterStyle = letterStyle.copyWith(
      fontWeight: FontWeight.w800,
      color: palette.accentColor,
    );
    final detailStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: palette.textOnSubpagePrimary,
      height: 1.1,
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row(
          label: '総合判定'.tr(lang),
          letter: summary.overallGrade.letter,
          letterKey: overallLetterKey,
          letterStyle: overallLetterStyle,
          detail: '',
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
        _row(
          label: 'テスト総合'.tr(lang),
          letter: summary.testGrade.letter,
          letterKey: testLetterKey,
          letterStyle: letterStyle,
          detail: summary.testGradeDetail,
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
        _row(
          label: '拡充度総合'.tr(lang),
          letter: summary.expansionGrade.letter,
          letterKey: expansionLetterKey,
          letterStyle: letterStyle,
          detail: summary.expansionGradeDetail,
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
      ],
    );
  }

  static TableRow _row({
    required String label,
    required String letter,
    required Key letterKey,
    required TextStyle letterStyle,
    required String detail,
    required TextStyle labelStyle,
    required TextStyle detailStyle,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: _NoWrapText(label, style: labelStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
          child: Text(letter, key: letterKey, style: letterStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(detail, style: detailStyle),
        ),
      ],
    );
  }
}

class _CategoryRow {
  const _CategoryRow({required this.date, required this.result});

  final String date;
  final String result;
}

typedef _CategorySectionData = ({
  Color color,
  String title,
  List<_CategoryRow> rows,
});

class _SectionMarker extends StatelessWidget {
  const _SectionMarker({required this.color, this.square = false});

  final Color color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: square
          ? BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            )
          : BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.section});

  final _CategorySectionData section;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SectionMarker(color: section.color),
            const SizedBox(width: 6),
            Expanded(
              child: _NoWrapText(
                section.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnSubpagePrimary,
                ),
              ),
            ),
          ],
        ),
        for (final row in section.rows)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  row.date,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textOnSubpageSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  row.result,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textOnSubpagePrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConversationRow {
  const _ConversationRow({
    required this.date,
    required this.jsst,
    required this.hit,
    required this.prep,
  });

  final String date;
  final String jsst;
  final String hit;
  final String prep;
}

/// JSST・的中度・PREPをまとめた3列の表。会話マーカーはレイヤーⅣのピンク。
class _ConversationBlock extends StatelessWidget {
  const _ConversationBlock({
    required this.color,
    required this.title,
    required this.rows,
  });

  final Color color;
  final String title;
  final List<_ConversationRow> rows;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return _ThreeValueTable(
      color: color,
      title: title,
      headers: ['JSST'.tr(lang), '的中度'.tr(lang), 'PREP'.tr(lang)],
      rows: [
        for (final row in rows)
          (date: row.date, values: [row.jsst, row.hit, row.prep]),
      ],
    );
  }
}

/// 発行時点の25マス拡充度（日常／ビジネス／シチュエーション）。マーカーは四角。
class _ExpansionBlock extends StatelessWidget {
  const _ExpansionBlock({
    required this.issuedAt,
    required this.summary,
    required this.lang,
  });

  final DateTime issuedAt;
  final DashboardSummary summary;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final expansion = summary.expansion;
    return _ThreeValueTable(
      color: kLayerColors[1],
      title: '25マス'.tr(lang),
      squareMarker: true,
      headers: [
        '日常'.tr(lang),
        'ビジネス'.tr(lang),
        'シチュエーション'.tr(lang),
      ],
      rows: [
        (
          date: _certificateTimestamp(issuedAt, lang),
          values: [
            expansion?.dailyDisplay ?? '0.0%',
            expansion?.businessDisplay ?? '0.0%',
            expansion?.situationalDisplay ?? '0.0%',
          ],
        ),
      ],
    );
  }
}

class _ThreeValueTable extends StatelessWidget {
  const _ThreeValueTable({
    required this.color,
    required this.title,
    required this.headers,
    required this.rows,
    this.squareMarker = false,
  });

  final Color color;
  final String title;
  final List<String> headers;
  final List<({String date, List<String> values})> rows;
  final bool squareMarker;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: palette.textOnSubpageSecondary,
    );
    final dateStyle = TextStyle(
      fontSize: 13,
      color: palette.textOnSubpageSecondary,
    );
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: palette.textOnSubpagePrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _SectionMarker(color: color, square: squareMarker),
            const SizedBox(width: 6),
            Expanded(
              child: _NoWrapText(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnSubpagePrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.15),
            1: FlexColumnWidth(0.85),
            2: FlexColumnWidth(1.05),
            3: FlexColumnWidth(1.15),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                _NoWrapText(
                  headers[0],
                  style: headerStyle,
                  align: TextAlign.center,
                ),
                _NoWrapText(
                  headers[1],
                  style: headerStyle,
                  align: TextAlign.center,
                ),
                _NoWrapText(
                  headers[2],
                  style: headerStyle,
                  align: TextAlign.center,
                ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(row.date, style: dateStyle),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.values[0],
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.values[1],
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.values[2],
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
