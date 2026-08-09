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
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../utils/history_timestamp.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// 起動画面の「…」→「成績証明証」から開く、1画面に収まる形の
/// 簡易証明書。発行日時・総合判定・JSST/発音/語彙の直近3件の結果を
/// [DashboardSummaryService]と同じ計算方法でまとめる（値は
/// [DashboardScreen]と常に一致する）。
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
    final scoring = await ScoringResultStorage().loadAll();
    final pronunciation = await PronunciationCheckStorage().loadAll();
    final vocabulary = await VocabularyCheckStorage().loadAll();
    if (!mounted) return;
    setState(() {
      _scoringResults = scoring.take(_rowsPerCategory).toList();
      _pronunciationChecks = pronunciation.take(_rowsPerCategory).toList();
      _vocabularyChecks = vocabulary.take(_rowsPerCategory).toList();
      _summary = DashboardSummaryService.build(
        scoringResults: scoring,
        pronunciationChecks: pronunciation,
        vocabularyChecks: vocabulary,
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
          date: formatHistoryTimestamp(saved.createdAt, languageCode: lang),
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
            : const _ConversationRow(date: 'ー', jsst: 'ー', hit: 'ー', prep: 'ー'),
    ];
  }

  List<_CategoryRow> _pronunciationRows(String lang) => _padRows([
    for (final check in _pronunciationChecks)
      _CategoryRow(
        date: formatHistoryTimestamp(check.createdAt, languageCode: lang),
        result: _pronunciationStars(check) ?? 'ー',
      ),
  ]);

  List<_CategoryRow> _vocabularyRows(String lang) => _padRows([
    for (final check in _vocabularyChecks)
      _CategoryRow(
        date: formatHistoryTimestamp(check.createdAt, languageCode: lang),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderRow(
                      issuedAt: _issuedAt,
                      summary: _summary,
                      lang: lang,
                    ),
                    const SizedBox(height: 12),
                    // JSST・的中度・PREPは同じレイヤーⅣ結果から同時に得られる
                    // ため、3列の表1つにまとめて表示する（語彙・発音は従来どおり
                    // 1列ずつ）。5ブロックを均等に縦積みすると1画面に収まらず
                    // 見切れていたため、会話表は行数分の高さだけ使い、
                    // 残りを語彙・発音に譲る。
                    _ConversationBlock(
                      color: kLayerColors[3],
                      title: '会話'.tr(lang),
                      rows: _conversationRows(lang),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _ResultsPanel(
                        sections: [
                          (
                            color: kLayerColors[0],
                            title: '語彙'.tr(lang),
                            rows: _vocabularyRows(lang),
                          ),
                          (
                            color: kLayerColors[4],
                            title: '発音'.tr(lang),
                            rows: _pronunciationRows(lang),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// アプリアイコン（左）＋発行日・発行時間・総合判定（右、縦並び）の見出し行。
/// 3行のうち総合判定だけを太字・大きめにして、メリハリをつける。
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.issuedAt,
    required this.summary,
    required this.lang,
  });

  final DateTime issuedAt;
  final DashboardSummary summary;
  final String lang;

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final dateText = formatLocalizedDate(issuedAt, lang);
    final timeText = '${_two(issuedAt.hour)}:${_two(issuedAt.minute)}';
    final metaStyle = TextStyle(
      fontSize: 13,
      color: palette.textOnSubpageSecondary,
    );
    final metaLabelStyle = metaStyle.copyWith(fontWeight: FontWeight.w600);
    final gradeLabelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: palette.textOnSubpageSecondary,
    );
    final gradeValueStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: palette.accentColor,
    );

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
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${'発行日'.tr(lang)}：', style: metaLabelStyle),
                    TextSpan(text: dateText, style: metaStyle),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${'発行時間'.tr(lang)}：',
                      style: metaLabelStyle,
                    ),
                    TextSpan(text: timeText, style: metaStyle),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // ベトナム語「Đánh giá tổng hợp」等、言語によってラベルが長く
              // 折り返すと2行目に「(3.8)」だけ浮いて見た目が崩れるため、
              // FittedBoxで1行に収まる大きさへ自動縮小する
              // （[_ResultTitle]と同じ手法）。
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${'総合判定'.tr(lang)}：',
                        style: gradeLabelStyle,
                      ),
                      TextSpan(
                        text: summary.overallGradeDisplay,
                        style: gradeValueStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

/// 語彙 / 発音を枠線なしで1画面にまとめた結果パネル
/// （JSST・的中度・PREPは[_ConversationBlock]が別途まとめて表示する）。
class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.sections});

  final List<_CategorySectionData> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Expanded(child: _CategoryBlock(section: sections[i])),
        ],
      ],
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: section.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              section.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: palette.textOnSubpagePrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        for (final row in section.rows)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
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

/// JSST・的中度・PREPをまとめた3列の表（[_CategoryBlock]と違い、他の
/// ブロックと縦に均等分割せず、行数（見出し+最大3件）ぶんの高さだけ使う）。
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
    final palette = AppColors.current;
    // 的中度・PREPの英語・ベトナム語訳（"Relevance"・"Độ trúng đích"等）は
    // JSSTより長く、見出し行の等幅3列だと折り返してしまうため、値行より
    // 小さいフォントサイズにする（列自体もJSST/PREPより広め、[columnWidths]参照）。
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: palette.textOnSubpagePrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Table(
          // 的中度（列2）は英語・ベトナム語訳がJSST/PREPより長いため、
          // 日付・JSST・PREPの幅を詰めてその分広めに割り当てる。
          columnWidths: const {
            0: FlexColumnWidth(1.15),
            1: FlexColumnWidth(0.65),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(0.65),
          },
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                Text(
                  'JSST'.tr(lang),
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
                Text(
                  '的中度'.tr(lang),
                  // 的中度列だけJSST/PREPより幅が広いため、右詰めだと数値が
                  // PREP側に寄って見える。見出し・数値とも中央寄せにして、
                  // JSSTとPREPのちょうど中間に来るようにする。
                  textAlign: TextAlign.center,
                  style: headerStyle,
                ),
                Text(
                  'PREP'.tr(lang),
                  textAlign: TextAlign.right,
                  style: headerStyle,
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
                      row.jsst,
                      textAlign: TextAlign.right,
                      style: valueStyle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.hit,
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.prep,
                      textAlign: TextAlign.right,
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
