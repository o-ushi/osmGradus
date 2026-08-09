part of 'layer1_vocab_screen.dart';

/// [CategorySelectField]相当。単語テストの出題レベル（N1/N2/N3/ランダム）を
/// タップで選ぶトリガー行。
class _Layer1LevelField extends StatelessWidget {
  const _Layer1LevelField({required this.selection, required this.onTap});

  final _Layer1LevelSelection selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              'レベル'.tr(lang),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.textOnScenePrimary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selection.labelText(lang),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.textOnScenePrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: palette.textOnScenePrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// [CategorySelectSheet]相当。出題レベルの選択シート。
/// 「レベル選択」配下のN1/N2/N3/その他はチェックボックスで複数選択でき、
/// 選ぶたびに[onChanged]で即座に反映される（[EpisodeSortSheet]と同じ、
/// シートを開いたまま調整を続けられる方式）。「ランダム」は全レベル対象の
/// 単一選択で、選ぶと同時にシートを閉じる。
class _Layer1LevelSelectSheet extends StatefulWidget {
  const _Layer1LevelSelectSheet({
    required this.selected,
    required this.onChanged,
  });

  final _Layer1LevelSelection selected;
  final ValueChanged<_Layer1LevelSelection> onChanged;

  static Future<void> show(
    BuildContext context, {
    required _Layer1LevelSelection selected,
    required ValueChanged<_Layer1LevelSelection> onChanged,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardFill,
      // N1/N2/N3/その他のチェックボックス分、既定の高さ制限に収まらない
      // 端末があるため、[LayerHelpSheet]と同じくisScrollControlled+内側の
      // スクロールで画面いっぱいまで広げられるようにする。
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _Layer1LevelSelectSheet(selected: selected, onChanged: onChanged),
    );
  }

  @override
  State<_Layer1LevelSelectSheet> createState() =>
      _Layer1LevelSelectSheetState();
}

class _Layer1LevelSelectSheetState extends State<_Layer1LevelSelectSheet> {
  static const _checkableLevels = [
    VocabularyLevel.n1,
    VocabularyLevel.n2,
    VocabularyLevel.n3,
    VocabularyLevel.other,
  ];

  late bool _isRandom = widget.selected.isRandom;
  late Set<VocabularyLevel> _checked = Set.of(widget.selected.levels);

  /// チェックボックスの切り替え。最後の1つは解除できない
  /// （必ず1レベル以上を選んだ状態を保つ）。
  void _toggle(VocabularyLevel level) {
    final next = Set.of(_checked);
    if (next.contains(level)) {
      if (next.length <= 1) return;
      next.remove(level);
    } else {
      next.add(level);
    }
    setState(() {
      _checked = next;
      _isRandom = false;
    });
    widget.onChanged(_Layer1LevelSelection.levels(next));
  }

  void _selectRandom() {
    setState(() => _isRandom = true);
    widget.onChanged(const _Layer1LevelSelection.random());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'レベル'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '単語帳_レベル選択'.tr(lang),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textOnCardPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final level in _checkableLevels)
                              LevelCheckboxRow(
                                label: _Layer1LevelSelection._levelLabelKey(
                                  level,
                                ).tr(lang),
                                checked: !_isRandom && _checked.contains(level),
                                onChanged: (_) => _toggle(level),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _LevelRow(
                        label: 'ランダム'.tr(lang),
                        selected: _isRandom,
                        onTap: _selectRandom,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: palette.accentColor),
          ],
        ),
      ),
    );
  }
}

/// [DiceTopicCard]相当。抽選した単語を表示する問題カード。
/// [wordVisible]がfalseの間は、カード枠は保ったまま文字を隠す
/// （ヒアリングのみのモード）。[questionNumber]/[totalQuestions]が
/// 揃っているときは、[PronunciationExerciseCard]と同じ「n / 10」の
/// 進捗表示を右上に添える。
class _Layer1WordCard extends StatelessWidget {
  const _Layer1WordCard({
    required this.word,
    required this.wordVisible,
    this.keyboardAwaitingStart = false,
    this.compact = false,
    this.questionNumber,
    this.totalQuestions,
  });

  final VocabularyEntry? word;
  final bool wordVisible;
  final bool keyboardAwaitingStart;
  final bool compact;
  final int? questionNumber;
  final int? totalQuestions;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final entry = word;

    final Widget content;
    if (keyboardAwaitingStart) {
      content = _Layer1EmptyInstruction(
        text: 'レイヤーⅠ_語彙_サイコロで開始'.tr(lang),
        color: palette.textOnCardPrimary,
      );
    } else if (entry == null) {
      content = _Layer1EmptyInstruction(
        text: 'レイヤーⅠ_語彙_空状態'.tr(lang),
        color: palette.textOnCardSecondary,
      );
    } else if (!wordVisible) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 22,
            color: palette.textOnCardSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'レイヤーⅠ_語彙_非表示中'.tr(lang),
              style: TextStyle(
                fontSize: 15,
                color: palette.textOnCardSecondary,
              ),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.word,
            style: TextStyle(
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: palette.textOnCardPrimary,
            ),
          ),
          if (entry.reading.isNotEmpty) ...[
            SizedBox(height: compact ? 2 : 6),
            Text(
              entry.reading,
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
        ],
      );
    }

    final numberLabel = questionNumber;
    final total = totalQuestions;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 0 : 160),
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (numberLabel != null && total != null) ...[
            Text(
              '$numberLabel / $total',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: palette.textOnCardSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
          ],
          Align(alignment: Alignment.centerLeft, child: content),
        ],
      ),
    );
  }
}

/// キーボード入力モードの回答欄。ENTERで[_Layer1VocabScreenState._onKeyboardSubmit]
/// を呼ぶ。
class _Layer1KeyboardAnswerField extends StatelessWidget {
  const _Layer1KeyboardAnswerField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmit,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
      style: TextStyle(fontSize: compact ? 16 : 17),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: compact ? 15 : 16),
        filled: true,
        fillColor: palette.cardFill,
        isDense: compact,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          borderSide: BorderSide(color: palette.accentColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 10 : 14,
        ),
      ),
    );
  }
}

/// キーボード入力で回答済みの問題を一覧し、修正する問題を選ぶ画面。
class _KeyboardAnswerReviewScreen extends StatelessWidget {
  const _KeyboardAnswerReviewScreen({
    required this.questions,
    required this.lang,
  });

  final List<VocabTestQuestion> questions;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final answered = <(int, VocabTestQuestion)>[
      for (var index = 0; index < questions.length; index++)
        if (questions[index].sttResult?.isNotEmpty ?? false)
          (index, questions[index]),
    ];

    return Scaffold(
      backgroundColor: palette.scene,
      appBar: AppBar(
        backgroundColor: palette.scene,
        foregroundColor: palette.textOnScenePrimary,
        iconTheme: IconThemeData(color: palette.textOnScenePrimary),
        titleTextStyle: TextStyle(
          color: palette.textOnScenePrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        title: Text('レイヤーⅠ_語彙_回答を修正'.tr(lang)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: answered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, rowIndex) {
            final (questionIndex, question) = answered[rowIndex];
            return Material(
              color: palette.cardFill,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('edit_answer_$questionIndex'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(context, questionIndex),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${'レイヤーⅠ_語彙_問'.tr(lang)} ${questionIndex + 1}',
                        style: TextStyle(
                          color: palette.textOnCardPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.play_arrow_rounded,
                        color: palette.accentColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.sttResult!,
                          style: TextStyle(
                            color: palette.textOnCardPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 空状態の案内文。[text]中の`{{dice}}`/`{{mic}}`を、画面上のサイコロ・マイクと
/// 同じアイコンに差し替えて表示する。
class _Layer1EmptyInstruction extends StatelessWidget {
  const _Layer1EmptyInstruction({required this.text, required this.color});

  final String text;
  final Color color;

  static final RegExp _token = RegExp(r'\{\{(dice|mic)\}\}');

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 15, height: 1.5, color: color);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _token.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final icon = match.group(1) == 'dice' ? Icons.casino : Icons.mic_rounded;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.left,
    );
  }
}
