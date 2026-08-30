import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/jsst_reference_samples.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, jsstCalibrationPreferences;
import '../../models/saved_scoring_result.dart';
import '../../models/scoring_models.dart';
import '../../services/app_logger.dart';
import '../../services/jsst_calibration_service.dart';
import '../../services/jsst_scoring_service.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import 'scoring_indicator_glossary_screen.dart';

/// レイヤーⅣの採点結果画面。osmWashabeの`ScoringResultView`の忠実な移植
/// （配色・レイアウトともにosmGradus独自の配色に寄せず、osmWashabeの
/// 白カード＋薄い影のライトテーマをそのまま使う）。判定まとめ・参考サンプル
/// （レベル4/9）との比較・発話内容・待遇表現・テキストタイプ・時間の使い方・
/// 開発者向けキャリブレーション・各指標の定義への導線まで、osmWashabeが
/// 持つ内容をすべて移植する。録音の聞き直しだけは対象外
/// （osmGradusは採点結果に音声を保存しないため）。
/// 採点完了後は自動遷移せず、レイヤーⅣの「例示」枠から
/// タップ（最新1件）または長押し（一覧）で開く。
class ScoringResultScreen extends StatelessWidget {
  const ScoringResultScreen({super.key, required this.result});

  final SavedScoringResult result;

  static const _background = Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final scoring = result.result;
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _background,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
      ),
      child: SwipeToCloseWrapper(
        child: Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: const _ResultTitle(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'JSSTの「待遇表現」「テキストタイプ」「時間の使い方（流暢さ）」の'
                        '3軸を近似したものです。公式の採点とは異なります。'
                    .tr(lang),
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 20),
              _JudgmentSummaryCard(result: scoring),
              const SizedBox(height: 16),
              _ReferenceComparisonCard(result: scoring),
              const SizedBox(height: 16),
              _PrepHitCard(saved: result),
              const SizedBox(height: 16),
              _SectionCard(
                title: '発話内容'.tr(lang),
                child: Text(
                  scoring.fullTranscript.isEmpty ? '—' : scoring.fullTranscript,
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '待遇表現'.tr(lang),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in scoring.keigo.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _KeigoCategoryRow(category: category),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'テキストタイプ'.tr(lang),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(
                      label: '発話単位数'.tr(lang),
                      value: '${scoring.complexity.totalUnits}',
                    ),
                    _MetricRow(
                      label: '複文・重文の数'.tr(lang),
                      value: '${scoring.complexity.complexUnitCount}',
                    ),
                    _MetricRow(
                      label: '複雑度'.tr(lang),
                      value:
                          '${(scoring.complexity.complexityRatio * 100).round()}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '時間の使い方'.tr(lang),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(
                      label: '発話枠'.tr(lang),
                      value:
                          '${scoring.fluency.allottedSeconds}${'秒'.tr(lang)}',
                    ),
                    _MetricRow(
                      label: '発話文字数'.tr(lang),
                      value: '${scoring.fluency.spokenCharacterCount}',
                    ),
                    _MetricRow(
                      label: '枠あたりの発話量'.tr(lang),
                      value:
                          '${scoring.fluency.charactersPerAllottedMinute.round()}${'字/分'.tr(lang)}',
                    ),
                    _MetricRow(
                      label: '推定発話時間'.tr(lang),
                      value:
                          '${scoring.fluency.estimatedSpeechSeconds.round()}${'秒'.tr(lang)}',
                    ),
                    _MetricRow(
                      label: '時間の利用率'.tr(lang),
                      value:
                          '${(scoring.fluency.timeUtilization * 100).round()}%',
                    ),
                    _MetricRow(
                      label: '推定沈黙の割合'.tr(lang),
                      value: '${(scoring.fluency.silenceRatio * 100).round()}%',
                    ),
                    _MetricRow(
                      label: '長い沈黙（4秒以上）'.tr(lang),
                      value: '${scoring.fluency.longPauseCount}${'回'.tr(lang)}',
                    ),
                    if (scoring.fluency.timeToFirstSpeechSeconds > 0)
                      _MetricRow(
                        label: '最初の発話まで'.tr(lang),
                        value:
                            '${scoring.fluency.timeToFirstSpeechSeconds.toStringAsFixed(1)}${'秒'.tr(lang)}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScoringIndicatorGlossaryScreen(),
                    ),
                  ),
                  child: Text('${'各指標の定義'.tr(lang)} ›'),
                ),
              ),
              if (AppLogger.instance.developerModeEnabled) ...[
                const SizedBox(height: 8),
                _CalibrationCard(
                  appLevel: JsstScoringService.combinedReferenceLevel(scoring),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle();

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final fg = Theme.of(context).appBarTheme.foregroundColor ?? Colors.black;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '採点結果'.tr(lang),
            style: TextStyle(
              color: fg,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          Text(
            '採点結果_試験版'.tr(lang),
            style: TextStyle(
              color: fg.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// PREP・的中度（Chrome AIによる参考評価、Step 8）。JSST（[scoring]）とは
/// 別軸の評価であり、レイヤーⅢの「結論→理由→例」点滅ガイドとは異なる
/// （ガイドは進行を促すだけでスコアは付けない）ため、見出しに必ず
/// 「評価」を付けて区別する。
class _PrepHitCard extends StatelessWidget {
  const _PrepHitCard({required this.saved});

  final SavedScoringResult saved;

  String _starDisplay(int stars) => '★' * stars + '☆' * (5 - stars);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return _SectionCard(
      title: 'PREP評価・的中度'.tr(lang),
      child: saved.hasAiEvaluation
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _JudgmentRow(
                  label: 'PREP評価'.tr(lang),
                  value: _starDisplay(saved.prepStars!),
                  valueBold: true,
                ),
                if (saved.prepAdvice != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(saved.prepAdvice!),
                  ),
                _JudgmentRow(
                  label: '的中度'.tr(lang),
                  value: _starDisplay(saved.hitStars!),
                  valueBold: true,
                ),
                if (saved.hitAdvice != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(saved.hitAdvice!),
                  ),
              ],
            )
          : saved.aiEvaluationUnparsedResponse != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AIの回答を解析できませんでした。回答原文のみ保存されています。'.tr(lang),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                Text(saved.aiEvaluationUnparsedResponse!),
              ],
            )
          : Text(
              'PREP評価・的中度は未送信です。'.tr(lang),
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
    );
  }
}

class _KeigoCategoryRow extends StatelessWidget {
  const _KeigoCategoryRow({required this.category});

  final KeigoCategoryResult category;

  String _label(String lang) => switch (category.category) {
    'sonkeigo' => '尊敬語'.tr(lang),
    'kenjougo' => '謙譲語'.tr(lang),
    'teineigo' => '丁寧語'.tr(lang),
    _ => category.category,
  };

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (category.matchedExpressions.isEmpty)
          Text(
            '検出された表現はありません'.tr(lang),
            style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final expression in category.matchedExpressions)
                Chip(
                  label: Text(expression),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _LabelValueRow(label: label, value: value, valueBold: true);
  }
}

/// ラベル＋値の2列行。長い文言・文字拡大でも折り返してオーバーフローしない。
class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.87)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: TextStyle(
                fontWeight: valueBold ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JudgmentRow extends StatelessWidget {
  const _JudgmentRow({
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              value,
              style: valueBold
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                  : const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _JudgmentSummaryCard extends StatelessWidget {
  const _JudgmentSummaryCard({required this.result});

  final ScoringResult result;

  String _keigoText(String lang) {
    final v = result.keigo.varietyScore;
    if (v == 0) {
      if (JsstScoringService.keigoPossiblyMissedByStt(result)) {
        return '丁寧語は検出されず（STTがです/ますを落とした可能性）'.tr(lang);
      }
      return '敬語の使用は検出されませんでした'.tr(lang);
    }
    if (v == 1) return '丁寧語のみ'.tr(lang);
    if (v == 2) {
      final hasSonkeigo = result.keigo.categories.any(
        (c) => c.category == 'sonkeigo' && c.matchedExpressions.isNotEmpty,
      );
      return (hasSonkeigo ? '丁寧語＋尊敬語' : '丁寧語＋謙譲語').tr(lang);
    }
    return '尊敬語・謙譲語・丁寧語のすべてを使用'.tr(lang);
  }

  String _complexityText(String lang) {
    final c = result.complexity;
    if (c.totalUnits == 0) return '—';
    if (c.complexityRatio == 0) return '単文のみ'.tr(lang);
    if (c.complexityRatio <= 0.10) return '単文が中心'.tr(lang);
    if (c.complexityRatio <= 0.33) return '複文・重文を使用'.tr(lang);
    return '複文・重文が中心'.tr(lang);
  }

  String _fluencyText(String lang) {
    final f = result.fluency;
    if (f.spokenCharacterCount == 0) return '発話が検出されませんでした'.tr(lang);
    if (f.timeUtilization >= 0.48 && f.silenceRatio < 0.45) {
      return '枠をよく使って話している'.tr(lang);
    }
    if (f.timeUtilization >= 0.38 || f.charactersPerAllottedMinute >= 85) {
      return 'ある程度まとめて話している'.tr(lang);
    }
    return '沈黙が多く、発話量が少ない'.tr(lang);
  }

  String _levelText(int? combined, String lang) {
    if (combined != null) return JsstReferenceSamples.levelLabel(combined);
    if (result.fluency.spokenCharacterCount == 0) return '—';
    final messageKey = JsstScoringService.referenceLevelEligibility(
      result,
    ).messageKey;
    return messageKey?.tr(lang) ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final combined = JsstScoringService.combinedReferenceLevel(result);
    return _SectionCard(
      title: '判定まとめ'.tr(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JudgmentRow(label: '待遇表現の幅'.tr(lang), value: _keigoText(lang)),
          _JudgmentRow(
            label: 'テキストの複雑さ'.tr(lang),
            value: _complexityText(lang),
          ),
          _JudgmentRow(label: '時間の使い方'.tr(lang), value: _fluencyText(lang)),
          const Divider(height: 24),
          _JudgmentRow(
            label: '参考レベル感'.tr(lang),
            value: _levelText(combined, lang),
            valueBold: true,
          ),
          const SizedBox(height: 4),
          Text(
            '3軸の参考値。公式採点とは大きく異なる場合があります。'.tr(lang),
            style: TextStyle(
              fontSize: 11,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceComparisonCard extends StatelessWidget {
  const _ReferenceComparisonCard({required this.result});

  final ScoringResult result;

  String _teineigoCell(ScoringResult scoring, {required bool isUser}) {
    final count = scoring.keigo.categories
        .where((c) => c.category == 'teineigo')
        .fold(0, (sum, c) => sum + c.matchedExpressions.length);
    if (count > 0) return '$count';
    if (isUser && JsstScoringService.keigoPossiblyMissedByStt(scoring)) {
      return '0*';
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final userLevel = JsstScoringService.combinedReferenceLevel(result);
    final allottedSeconds = JsstReferenceSamples.normalizeAllottedSeconds(
      result.session?.allottedSeconds ?? result.fluency.allottedSeconds,
    );
    final benchmarks = JsstReferenceSamples.forAllottedSeconds(allottedSeconds);
    final level4 = benchmarks.level4;
    final level9 = benchmarks.level9;

    return _SectionCard(
      title: '参考サンプルとの比較'.tr(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参考サンプル_説明'.trFmt(lang, ['$allottedSeconds']),
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final baseWidth = constraints.maxWidth;
              final textScale = MediaQuery.textScalerOf(
                context,
              ).scale(1.0).clamp(1.0, 2.5);
              final tableWidth = baseWidth * textScale;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(2.4),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          const SizedBox.shrink(),
                          _ComparisonHeader('あなた'.tr(lang), emphasized: true),
                          _ComparisonHeader('レベル4参考'.tr(lang)),
                          _ComparisonHeader('レベル9参考'.tr(lang)),
                        ],
                      ),
                      _comparisonRow(
                        '参考レベル感'.tr(lang),
                        JsstReferenceSamples.levelLabel(userLevel),
                        JsstReferenceSamples.levelLabel(level4.combinedLevel),
                        JsstReferenceSamples.levelLabel(level9.combinedLevel),
                        emphasizeFirst: true,
                      ),
                      _comparisonRow(
                        '枠あたりの発話量'.tr(lang),
                        '${result.fluency.charactersPerAllottedMinute.round()}',
                        '${level4.result.fluency.charactersPerAllottedMinute.round()}',
                        '${level9.result.fluency.charactersPerAllottedMinute.round()}',
                      ),
                      _comparisonRow(
                        '時間の利用率'.tr(lang),
                        '${(result.fluency.timeUtilization * 100).round()}%',
                        '${(level4.result.fluency.timeUtilization * 100).round()}%',
                        '${(level9.result.fluency.timeUtilization * 100).round()}%',
                      ),
                      _comparisonRow(
                        '推定沈黙の割合'.tr(lang),
                        '${(result.fluency.silenceRatio * 100).round()}%',
                        '${(level4.result.fluency.silenceRatio * 100).round()}%',
                        '${(level9.result.fluency.silenceRatio * 100).round()}%',
                      ),
                      _comparisonRow(
                        '複雑度'.tr(lang),
                        '${(result.complexity.complexityRatio * 100).round()}%',
                        '${(level4.result.complexity.complexityRatio * 100).round()}%',
                        '${(level9.result.complexity.complexityRatio * 100).round()}%',
                      ),
                      _comparisonRow(
                        '丁寧語検出数'.tr(lang),
                        _teineigoCell(result, isUser: true),
                        _teineigoCell(level4.result, isUser: false),
                        _teineigoCell(level9.result, isUser: false),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (JsstScoringService.keigoPossiblyMissedByStt(result)) ...[
            const SizedBox(height: 8),
            Text(
              '* ${'丁寧語は検出されず（STTがです/ますを落とした可能性）'.tr(lang)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final sample in benchmarks.all)
            Material(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${sample.label}: ${'参考抜粋を見る'.tr(lang)}',
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sample.excerpt,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  TableRow _comparisonRow(
    String label,
    String user,
    String level4,
    String level9, {
    bool emphasizeFirst = false,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
          ),
        ),
        _ComparisonCell(user, emphasized: emphasizeFirst),
        _ComparisonCell(level4),
        _ComparisonCell(level9),
      ],
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader(this.text, {this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: emphasized ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell(this.text, {this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
          fontSize: emphasized ? 14 : 13,
        ),
      ),
    );
  }
}

/// 開発者モード専用のキャリブレーションカード。osmWashabeの`_CalibrationCard`
/// の移植。自己評価（JSST 1〜10）を繰り返し入力することでアプリの評価傾向
/// （甘め/辛め）を推定し、補正後レベルを表示する。
class _CalibrationCard extends StatefulWidget {
  const _CalibrationCard({required this.appLevel});

  final int? appLevel;

  @override
  State<_CalibrationCard> createState() => _CalibrationCardState();
}

class _CalibrationCardState extends State<_CalibrationCard> {
  late int _selectedJsstLevel;

  @override
  void initState() {
    super.initState();
    final appLevel = widget.appLevel;
    _selectedJsstLevel = appLevel != null
        ? JsstCalibrationService.internalToJsstDefault(appLevel)
        : 5;
  }

  void _applyCalibration() {
    final appLevel = widget.appLevel;
    if (appLevel == null) return;
    final userInternal = JsstCalibrationService.jsstLevelToInternal(
      _selectedJsstLevel,
    );
    final newBias = JsstCalibrationService.updateBias(
      currentBias: jsstCalibrationPreferences.bias,
      userInternalLevel: userInternal,
      appInternalLevel: appLevel,
    );
    // update()はメモリ上の値を同期的に更新してから永続化するため、
    // setState()の前にawaitしなくても表示にはすぐ反映される。永続化の完了
    // 自体は待つ必要がないのでunawaited()で明示する。
    unawaited(
      jsstCalibrationPreferences.update(
        bias: newBias,
        sampleCount: jsstCalibrationPreferences.sampleCount + 1,
      ),
    );
    setState(() {});
  }

  void _resetCalibration() {
    unawaited(jsstCalibrationPreferences.clear());
    setState(() {});
  }

  String _biasLabel(String lang) => JsstCalibrationService.biasLabel(
    jsstCalibrationPreferences.bias,
  ).tr(lang);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final bias = jsstCalibrationPreferences.bias;
    final sampleCount = jsstCalibrationPreferences.sampleCount;
    final appLevel = widget.appLevel;
    final adjustedLevel = JsstCalibrationService.adjustedLevel(appLevel, bias);
    final biasSign = bias >= 0 ? '+' : '';

    return _SectionCard(
      title: 'キャリブレーション（開発者）'.tr(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (appLevel == null)
            Text(
              '参考レベルが算出できませんでした。キャリブレーションは利用できません。'.tr(lang),
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            )
          else ...[
            _LabelValueRow(
              label: '補正係数'.tr(lang),
              value: '$biasSign${bias.toStringAsFixed(2)}',
              valueBold: true,
            ),
            _LabelValueRow(
              label: '評価傾向'.tr(lang),
              value: _biasLabel(lang),
              valueBold: true,
            ),
            _LabelValueRow(
              label: '学習回数'.tr(lang),
              value: '$sampleCount ${'回'.tr(lang)}',
            ),
            if (adjustedLevel != null)
              _LabelValueRow(
                label: '補正後レベル'.tr(lang),
                value: JsstReferenceSamples.levelLabel(adjustedLevel),
                valueBold: true,
              ),
            const Divider(height: 24),
            Text(
              '自己評価を入力 (JSST 1–10)'.tr(lang),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '1',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                ),
                Expanded(
                  child: Slider(
                    value: _selectedJsstLevel.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_selectedJsstLevel',
                    onChanged: (v) =>
                        setState(() => _selectedJsstLevel = v.round()),
                  ),
                ),
                Text(
                  '10',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ],
            ),
            Center(
              child: Text(
                'JSST $_selectedJsstLevel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resetCalibration,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('リセット'.tr(lang)),
                ),
                ElevatedButton(
                  onPressed: _applyCalibration,
                  child: Text('適用'.tr(lang)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
