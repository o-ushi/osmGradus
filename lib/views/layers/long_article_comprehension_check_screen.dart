import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article_comprehension_check.dart';
import '../../theme/app_colors.dart';

/// 長文読解フローの「1秒チェック」画面。文脈・ロジック理解を問う2択クイズ
/// （発話・発音は触らない）。回答後は正解/不正解と1行解説を同画面内に表示し、
/// 「トップへ戻る」（または2秒後の自動遷移）で[onComplete]を呼ぶ。
class LongArticleComprehensionCheckScreen extends StatefulWidget {
  const LongArticleComprehensionCheckScreen({
    super.key,
    required this.check,
    required this.onComplete,
  });

  final LongArticleComprehensionCheck check;

  /// 「トップへ戻る」タップ、または回答から2秒後に呼ぶ。
  final VoidCallback onComplete;

  @override
  State<LongArticleComprehensionCheckScreen> createState() =>
      _LongArticleComprehensionCheckScreenState();
}

class _LongArticleComprehensionCheckScreenState
    extends State<LongArticleComprehensionCheckScreen> {
  String? _selectedOption;
  Timer? _autoCompleteTimer;

  bool get _answered => _selectedOption != null;
  bool get _isCorrect => _selectedOption == widget.check.correctOption;

  void _select(String option) {
    if (_answered) return;
    setState(() => _selectedOption = option);
    _autoCompleteTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onComplete();
    });
  }

  _OptionVisualState _stateFor(String option) {
    if (!_answered) return _OptionVisualState.idle;
    if (_selectedOption != option) return _OptionVisualState.disabled;
    return _isCorrect
        ? _OptionVisualState.correct
        : _OptionVisualState.incorrect;
  }

  @override
  void dispose() {
    _autoCompleteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final check = widget.check;

    return Material(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '長文読解_1秒チェック_見出し'.tr(lang),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnScenePrimary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      check.question,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.textOnScenePrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _OptionCard(
                      label: 'A',
                      text: check.optionA,
                      state: _stateFor('A'),
                      onTap: _answered ? null : () => _select('A'),
                    ),
                    const SizedBox(height: 12),
                    _OptionCard(
                      label: 'B',
                      text: check.optionB,
                      state: _stateFor('B'),
                      onTap: _answered ? null : () => _select('B'),
                    ),
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      _ResultCard(
                        isCorrect: _isCorrect,
                        correctOption: check.correctOption,
                        explanation: check.explanation,
                      ),
                    ],
                  ],
                ),
              ),
              if (_answered) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentColor,
                      foregroundColor: palette.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '長文読解_1秒チェック_トップへ戻る'.tr(lang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _OptionVisualState { idle, disabled, correct, incorrect }

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final _OptionVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final (borderColor, fillColor, textColor) = switch (state) {
      _OptionVisualState.idle => (
        palette.cardBorder,
        palette.cardFill,
        palette.textOnCardPrimary,
      ),
      _OptionVisualState.disabled => (
        palette.cardBorder,
        palette.cardFill,
        palette.textOnCardSecondary,
      ),
      _OptionVisualState.correct => (
        Colors.green,
        Colors.green.withValues(alpha: 0.12),
        palette.textOnCardPrimary,
      ),
      _OptionVisualState.incorrect => (
        Colors.redAccent,
        Colors.redAccent.withValues(alpha: 0.12),
        palette.textOnCardPrimary,
      ),
    };
    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label. ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
              if (state == _OptionVisualState.correct)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              if (state == _OptionVisualState.incorrect)
                const Icon(
                  Icons.cancel_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.isCorrect,
    required this.correctOption,
    required this.explanation,
  });

  final bool isCorrect;
  final String correctOption;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final accent = isCorrect ? Colors.green : Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                (isCorrect ? '長文読解_1秒チェック_正解' : '長文読解_1秒チェック_不正解').tr(lang),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 6),
            Text(
              '長文読解_1秒チェック_正解表示'.trFmt(lang, [correctOption]),
              style: TextStyle(
                fontSize: 13,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            explanation,
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }
}
