part of 'vocabulary_sheet.dart';

class _DeckBackdrop extends StatelessWidget {
  const _DeckBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: _GlowOrb(color: kLayerColors[1], size: 220),
        ),
        Positioned(
          top: 140,
          left: -70,
          child: _GlowOrb(color: kLayerColors[2], size: 180),
        ),
        Positioned(
          bottom: 120,
          right: -20,
          child: _GlowOrb(color: kLayerColors[3], size: 160),
        ),
        Positioned(
          bottom: -30,
          left: 40,
          child: _GlowOrb(color: kLayerColors[4], size: 140),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _DeckTopBar extends StatelessWidget {
  const _DeckTopBar({
    required this.lang,
    required this.entryCount,
    required this.canShuffle,
    required this.isManaging,
    required this.selectedLevels,
    required this.onFilterChanged,
    required this.onClose,
    required this.onShuffle,
    required this.onToggleManage,
  });

  final String lang;
  final int entryCount;
  final bool canShuffle;
  final bool isManaging;
  final Set<VocabularyLevel> selectedLevels;
  final ValueChanged<Set<VocabularyLevel>> onFilterChanged;
  final VoidCallback onClose;
  final VoidCallback onShuffle;
  final VoidCallback onToggleManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LevelFilterButton(
                  lang: lang,
                  selectedLevels: selectedLevels,
                  onChanged: onFilterChanged,
                ),
                if (entryCount > 0)
                  Text(
                    '$entryCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (isManaging)
            IconButton(
              onPressed: onToggleManage,
              icon: const Icon(Icons.done_rounded, color: Colors.white),
              tooltip: '完了'.tr(lang),
            )
          else ...[
            IconButton(
              onPressed: entryCount > 0 ? onToggleManage : null,
              icon: Icon(
                Icons.format_list_bulleted_rounded,
                color: entryCount > 0
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
              ),
              tooltip: '単語帳_一覧'.tr(lang),
            ),
            IconButton(
              onPressed: canShuffle ? onShuffle : null,
              icon: Icon(
                Icons.shuffle_rounded,
                color: canShuffle
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
              ),
              tooltip: 'ランダム'.tr(lang),
            ),
          ],
        ],
      ),
    );
  }
}

/// 単語帳タイトルの代わりに置く、レベル絞り込み用ボタン。タップすると
/// レイヤーⅠのレベル選択シート（[LevelCheckboxRow]）と同じ配色・体裁の
/// ボトムシートを開き、N1/N2/N3/その他を複数選択できる。文字ラベルは
/// 出さず、絞り込み中はアイコンを塗りつぶし＋アクセント色にするだけで
/// 状態を示す（件数はこのボタンの隣に表示する）。
class _LevelFilterButton extends StatelessWidget {
  const _LevelFilterButton({
    required this.lang,
    required this.selectedLevels,
    required this.onChanged,
  });

  final String lang;
  final Set<VocabularyLevel> selectedLevels;
  final ValueChanged<Set<VocabularyLevel>> onChanged;

  static const _allLevels = VocabularyLevel.values;

  static String levelLabel(VocabularyLevel level, String lang) =>
      level == VocabularyLevel.other
      ? '単語帳_レベルその他'.tr(lang)
      : level.storageKey.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final isFiltered =
        selectedLevels.isNotEmpty && selectedLevels.length < _allLevels.length;
    return IconButton(
      onPressed: () => _LevelFilterSheet.show(
        context,
        lang: lang,
        selected: selectedLevels,
        onChanged: onChanged,
      ),
      icon: Icon(
        isFiltered ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
        color: isFiltered ? palette.cardAccent : Colors.white,
      ),
      tooltip: '単語帳_フィルタ_タイトル'.tr(lang),
    );
  }
}

/// N1/N2/N3/その他を複数選択するボトムシート。レイヤーⅠの出題レベル選択
/// シート（`_Layer1LevelSelectSheet`）と同じ`palette.cardFill`背景・
/// ドラッグハンドル・[LevelCheckboxRow]を使い、アプリ全体で見た目を揃える。
/// チェックのたびに[onChanged]で即座に反映し、シートは開いたままにする。
class _LevelFilterSheet extends StatefulWidget {
  const _LevelFilterSheet({
    required this.lang,
    required this.selected,
    required this.onChanged,
  });

  final String lang;
  final Set<VocabularyLevel> selected;
  final ValueChanged<Set<VocabularyLevel>> onChanged;

  static Future<void> show(
    BuildContext context, {
    required String lang,
    required Set<VocabularyLevel> selected,
    required ValueChanged<Set<VocabularyLevel>> onChanged,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LevelFilterSheet(
        lang: lang,
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_LevelFilterSheet> createState() => _LevelFilterSheetState();
}

class _LevelFilterSheetState extends State<_LevelFilterSheet> {
  static const _allLevels = VocabularyLevel.values;
  late Set<VocabularyLevel> _checked = Set.of(widget.selected);

  void _toggle(VocabularyLevel level) {
    final next = Set.of(_checked);
    if (next.contains(level)) {
      next.remove(level);
    } else {
      next.add(level);
    }
    setState(() => _checked = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SafeArea(
      top: false,
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
              '単語帳_フィルタ_タイトル'.tr(widget.lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final level in _allLevels)
              LevelCheckboxRow(
                label: _LevelFilterButton.levelLabel(level, widget.lang),
                checked: _checked.contains(level),
                onChanged: (_) => _toggle(level),
              ),
          ],
        ),
      ),
    );
  }
}

/// 絞り込みに一致する語が無いときの表示。単語帳自体が空の[_EmptyDeck]とは
/// 区別し、フィルタを外せばすぐ復帰できることを伝える。
class _NoFilterMatches extends StatelessWidget {
  const _NoFilterMatches({required this.lang, required this.onClearFilter});

  final String lang;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              '単語帳_フィルタ_該当なし'.tr(lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClearFilter,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text('単語帳_フィルタ_解除'.tr(lang)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckView extends StatelessWidget {
  const _DeckView({
    required this.lang,
    required this.entries,
    required this.order,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onDelete,
    required this.onSpeak,
    required this.onEdit,
  });

  final String lang;
  final List<VocabularyEntry> entries;
  final List<int> order;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(String id) onDelete;
  final ValueChanged<VocabularyEntry> onSpeak;
  final ValueChanged<VocabularyEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDots = constraints.maxHeight >= 160 && entries.length > 1;
        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (entries.length > 1) ...[
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _DeckShadowCard(
                          offsetY: 18,
                          scale: 0.9,
                          opacity: 0.22,
                          color:
                              kLayerColors[(currentIndex + 2) %
                                  kLayerColors.length],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _DeckShadowCard(
                          offsetY: 9,
                          scale: 0.95,
                          opacity: 0.38,
                          color:
                              kLayerColors[(currentIndex + 1) %
                                  kLayerColors.length],
                        ),
                      ),
                    ),
                  ],
                  PageView.builder(
                    controller: pageController,
                    itemCount: entries.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, pageIndex) {
                      final entryIndex = order[pageIndex];
                      final entry = entries[entryIndex];
                      final isBuiltin = JlptVocabBankService.isBuiltinId(
                        entry.id,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _FlipFlashcard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          color: kLayerColors[entryIndex % kLayerColors.length],
                          lang: lang,
                          onDelete: isBuiltin ? null : () => onDelete(entry.id),
                          onSpeak: () => onSpeak(entry),
                          onEdit: () => onEdit(entry),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (showDots) ...[
              const SizedBox(height: 8),
              if (entries.length > 12)
                Text(
                  '${currentIndex + 1} / ${entries.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(entries.length, (index) {
                    final active = index == currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _DeckShadowCard extends StatelessWidget {
  const _DeckShadowCard({
    required this.offsetY,
    required this.scale,
    required this.opacity,
    required this.color,
  });

  final double offsetY;
  final double scale;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FlipFlashcard extends StatefulWidget {
  const _FlipFlashcard({
    super.key,
    required this.entry,
    required this.color,
    required this.lang,
    required this.onDelete,
    required this.onSpeak,
    required this.onEdit,
  });

  final VocabularyEntry entry;
  final Color color;
  final String lang;
  final VoidCallback? onDelete;
  final VoidCallback onSpeak;
  final VoidCallback onEdit;

  @override
  State<_FlipFlashcard> createState() => _FlipFlashcardState();
}

class _FlipFlashcardState extends State<_FlipFlashcard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    HapticFeedback.lightImpact();
    if (_showFront) {
      await _controller.forward();
    } else {
      await _controller.reverse();
    }
    if (!mounted) return;
    setState(() => _showFront = !_showFront);
  }

  @override
  Widget build(BuildContext context) {
    final translationLabel =
        (widget.entry.translationLang == 'en' ? '単語帳_英語' : '単語帳_ベトナム語').tr(
          widget.lang,
        );
    return SizedBox.expand(
      child: GestureDetector(
        onTap: _flip,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onEdit();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * math.pi;
            final isUnder = angle >= math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isUnder
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _FlashcardFace(
                        label: translationLabel,
                        text: widget.entry.translation,
                        color: widget.color,
                        footer: widget.onDelete == null
                            ? const SizedBox(height: 48)
                            : IconButton(
                                onPressed: widget.onDelete,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    )
                  : _FlashcardFace(
                      label: '単語帳_日本語'.tr(widget.lang),
                      text: widget.entry.word,
                      reading: widget.entry.reading,
                      example: widget.entry.exampleSentence,
                      color: widget.color,
                      footer: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: widget.onSpeak,
                            icon: const Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                            tooltip: '読み上げ'.tr(widget.lang),
                          ),
                          Icon(
                            Icons.touch_app_rounded,
                            color: Colors.white.withValues(alpha: 0.72),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({
    required this.label,
    required this.text,
    required this.color,
    required this.footer,
    this.reading = '',
    this.example = '',
  });

  final String label;
  final String text;
  final Color color;
  final Widget footer;

  /// [text]の読み仮名。日本語面のみ渡す（訳語面は既定の空文字のまま）。
  final String reading;

  /// [text]を使った例文。日本語面のみ渡す（訳語面は既定の空文字のまま）。
  final String example;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.18)!],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ラベル＋フッター（IconButton 48）＋余白が確実に収まる高さだけフル表示。
            final showChrome = constraints.maxHeight >= 220;
            final compact = constraints.maxHeight < 160;
            final fontSize = compact ? 22.0 : 34.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                showChrome ? 24 : 12,
                compact ? 16 : 24,
                showChrome ? 16 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showChrome)
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showChrome && reading.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              reading,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: compact ? 13 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    constraints.maxWidth -
                                    (compact ? 32 : 48),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (showChrome && example.isNotEmpty)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                example,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 22,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showChrome)
                    Align(alignment: Alignment.center, child: footer),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.lang, required this.onAddTap});

  final String lang;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 280,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_rounded,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '登録済みの単語はありません'.tr(lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onAddTap,
                  icon: const Icon(Icons.add_rounded),
                  label: Text('単語帳_最初の1語'.tr(lang)),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.cardAccent,
                    foregroundColor: palette.onFill(palette.cardAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
