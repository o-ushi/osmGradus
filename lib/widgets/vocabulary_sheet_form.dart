part of 'vocabulary_sheet.dart';

class _DeckBottomBar extends StatelessWidget {
  const _DeckBottomBar({
    required this.lang,
    required this.currentIndex,
    required this.total,
    required this.showProgress,
    required this.showAddPanel,
    required this.isEditing,
    required this.wordController,
    required this.readingController,
    required this.exampleController,
    required this.translationController,
    required this.translationLang,
    required this.onLangChange,
    required this.level,
    required this.onLevelChange,
    required this.onToggleAddPanel,
    required this.onSubmit,
  });

  final String lang;
  final int currentIndex;
  final int total;
  final bool showProgress;
  final bool showAddPanel;
  final bool isEditing;
  final TextEditingController wordController;
  final TextEditingController readingController;
  final TextEditingController exampleController;
  final TextEditingController translationController;
  final String translationLang;
  final ValueChanged<String> onLangChange;
  final VocabularyLevel level;
  final ValueChanged<VocabularyLevel> onLevelChange;
  final VoidCallback onToggleAddPanel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: palette.cardFill,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showProgress && total > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${currentIndex + 1} / $total',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textOnCardSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (showAddPanel) ...[
              if (isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '編集'.tr(lang),
                        style: TextStyle(
                          color: palette.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              TextField(
                controller: wordController,
                style: TextStyle(
                  color: palette.textOnCardPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: _inputDecoration(palette, '単語（日本語）'.tr(lang)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: readingController,
                style: TextStyle(color: palette.textOnCardPrimary),
                decoration: _inputDecoration(palette, '単語帳_読み方'.tr(lang)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exampleController,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(color: palette.textOnCardPrimary),
                decoration: _inputDecoration(palette, '単語帳_例文'.tr(lang)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '単語帳_訳の言語'.tr(lang),
                  style: TextStyle(
                    color: palette.textOnCardSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'vi',
                    label: Text(
                      '単語帳_ベトナム語'.tr(lang),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(
                      '単語帳_英語'.tr(lang),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {translationLang},
                onSelectionChanged: (selection) =>
                    onLangChange(selection.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: palette.subpageBackground,
                  foregroundColor: palette.textOnCardSecondary,
                  selectedBackgroundColor: palette.accentColor,
                  selectedForegroundColor: palette.onAccent,
                  side: BorderSide(color: palette.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'レベル'.tr(lang),
                  style: TextStyle(
                    color: palette.textOnCardSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _LevelSegmentedRow(
                lang: lang,
                level: level,
                onChanged: onLevelChange,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '単語帳_訳ヒント'.tr(lang),
                  style: TextStyle(
                    color: palette.textOnCardSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: translationController,
                      minLines: 3,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: palette.textOnCardPrimary),
                      decoration: _inputDecoration(
                        palette,
                        (translationLang == 'en' ? '英語訳' : 'ベトナム語訳').tr(lang),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentColor,
                      foregroundColor: palette.onAccent,
                      minimumSize: const Size(56, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.check_rounded, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: onToggleAddPanel,
              icon: Icon(showAddPanel ? Icons.expand_more : Icons.add_rounded),
              label: Text(
                showAddPanel ? 'キャンセル'.tr(lang) : '単語帳_新しい単語'.tr(lang),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: showAddPanel
                    ? palette.subpageBackground
                    : palette.cardAccent,
                foregroundColor: showAddPanel
                    ? palette.textOnCardPrimary
                    : palette.onFill(palette.cardAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppPalette palette, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.textOnCardSecondary),
      filled: true,
      fillColor: palette.subpageBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accentColor, width: 1.5),
      ),
    );
  }
}

/// レベル選択（N1/N2/N3/その他）専用の連結ピル行。
///
/// [SegmentedButton]は内部で全セグメントを常に等幅にする（`_isExpanded`の
/// 有無に関わらず、最も幅を要するセグメントに合わせて残りも同じ幅へ揃える）
/// ため、「N1」「N2」「N3」のような短いラベルと並ぶ「その他」（英語では
/// "Other"）だけが４分割の枠に収まらず折り返してしまう。ここでは見た目
/// （角丸で連結したピル・選択時は塗りつぶし）だけ[SegmentedButton]に揃えつつ、
/// セグメントごとに[Expanded.flex]で幅の比率を変えられる自前の行にする。
class _LevelSegmentedRow extends StatelessWidget {
  const _LevelSegmentedRow({
    required this.lang,
    required this.level,
    required this.onChanged,
  });

  final String lang;
  final VocabularyLevel level;
  final ValueChanged<VocabularyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final segments = <(VocabularyLevel, String, int)>[
      (VocabularyLevel.n1, 'N1', 2),
      (VocabularyLevel.n2, 'N2', 2),
      (VocabularyLevel.n3, 'N3', 2),
      (VocabularyLevel.other, '単語帳_レベルその他'.tr(lang), 3),
    ];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) Container(width: 1, color: palette.cardBorder),
            Expanded(
              flex: segments[i].$3,
              child: _LevelSegment(
                label: segments[i].$2,
                selected: level == segments[i].$1,
                onTap: () => onChanged(segments[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelSegment extends StatelessWidget {
  const _LevelSegment({
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
    return Material(
      color: selected ? palette.accentColor : palette.subpageBackground,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? palette.onAccent
                      : palette.textOnCardSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

