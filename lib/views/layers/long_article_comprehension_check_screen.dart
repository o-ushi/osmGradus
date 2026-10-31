import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article_comprehension_check.dart';
import '../../theme/app_colors.dart';

/// 長文読解フローの「1秒チェック」画面。文脈・ロジック理解を問う2択クイズ
/// （発話・発音は触らない）。回答後は正解/不正解と1行解説を同画面内に表示し、
/// 完了ボタンのタップで[onComplete]を呼ぶ（自動遷移はしない。解説を
/// 読み終えるまでの時間は学習者ごとに違うため）。[continuesToVocabTest]が
/// trueのときは、このボタンが実際には「トップ（3択）」ではなく語彙テストへ
/// 進むため、ボタン文言を「トップへ戻る」から差し替える（Step 10レビュー：
/// 語彙テストが続く場合にボタン文言だけが旧動線のままだった不整合の修正）。
class LongArticleComprehensionCheckScreen extends StatefulWidget {
  const LongArticleComprehensionCheckScreen({
    super.key,
    required this.check,
    required this.onComplete,
    this.continuesToVocabTest = false,
  });

  final LongArticleComprehensionCheck check;

  /// 完了ボタンのタップで呼ぶ。引数は選んだ選択肢（`"A"` / `"B"`）。
  /// [continuesToVocabTest]により3択復帰／語彙テスト開始のどちらかに
  /// つながる（分岐は呼び出し元が持つ）。
  final ValueChanged<String> onComplete;

  /// trueなら、このチェックの後に語彙テストが続く（語彙テスト用単語がある）。
  /// ボタン文言を「トップへ戻る」ではなく「語彙テストへ進む」にする。
  final bool continuesToVocabTest;

  @override
  State<LongArticleComprehensionCheckScreen> createState() =>
      _LongArticleComprehensionCheckScreenState();
}

class _LongArticleComprehensionCheckScreenState
    extends State<LongArticleComprehensionCheckScreen> {
  String? _selectedOption;

  bool get _answered => _selectedOption != null;
  bool get _isCorrect => _selectedOption == widget.check.correctOption;

  void _select(String option) {
    if (_answered) return;
    setState(() => _selectedOption = option);
  }

  _OptionVisualState _stateFor(String option) {
    if (!_answered) return _OptionVisualState.idle;
    if (_selectedOption != option) return _OptionVisualState.disabled;
    return _isCorrect
        ? _OptionVisualState.correct
        : _OptionVisualState.incorrect;
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
                      _ResultCard(isCorrect: _isCorrect, check: check),
                    ],
                  ],
                ),
              ),
              if (_answered) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedOption == null
                        ? null
                        : () => widget.onComplete(_selectedOption!),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentColor,
                      foregroundColor: palette.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      (widget.continuesToVocabTest
                              ? '長文読解_1秒チェック_語彙テストへ'
                              : '長文読解_1秒チェック_トップへ戻る')
                          .tr(lang),
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
      // 塗りは不透明度0.12の緑/赤をシーンの濃紺に重ねた暗めの色になるため、
      // カード用の暗い文字色（textOnCardPrimary）ではなく、シーン用の白文字
      // （textOnScenePrimary）を使う。
      _OptionVisualState.correct => (
        Colors.green,
        Colors.green.withValues(alpha: 0.12),
        palette.textOnScenePrimary,
      ),
      _OptionVisualState.incorrect => (
        Colors.redAccent,
        Colors.redAccent.withValues(alpha: 0.12),
        palette.textOnScenePrimary,
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
  const _ResultCard({required this.isCorrect, required this.check});

  final bool isCorrect;
  final LongArticleComprehensionCheck check;

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
              '長文読解_1秒チェック_正解表示'.trFmt(lang, [check.correctOption]),
              style: TextStyle(
                fontSize: 13,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            check.explanationFor(lang),
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }
}
