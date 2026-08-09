import 'package:flutter/material.dart';

import '../../data/long_article_omakase_topics.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/long_article_generation_settings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';

/// 長文読解フローの入口。キーワード・JLPTレベル・文体の硬さ・目安の長さを
/// 選び、「開始する」で[LongArticleGenerateScreen]（生成・貼付）へ進む。
/// osmCogitoの`CogitoSetupScreen`を移植する土台だが、Cogitoセッション本体
/// （関連質問・ラウンド数）は移植しない。
class LongArticleKeywordScreen extends StatefulWidget {
  const LongArticleKeywordScreen({super.key, required this.onNext});

  final ValueChanged<LongArticleGenerationSettings> onNext;

  @override
  State<LongArticleKeywordScreen> createState() =>
      _LongArticleKeywordScreenState();
}

class _LongArticleKeywordScreenState extends State<LongArticleKeywordScreen> {
  final _keywordController = TextEditingController();
  var _jlptLevel = LongArticleJlptLevel.n2;
  var _looseness = LongArticleLooseness.level3;
  var _length = LongArticleLength.chars600;
  var _keywordOmakase = false;
  var _keywordBeforeOmakase = '';

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool get _canNext => _keywordController.text.trim().isNotEmpty;

  /// おまかせON：AIに丸投げする曖昧な指示文ではなく、あらかじめ用意した
  /// 雑多なお題候補（[longArticleOmakaseTopics]）からこちら側でランダムに
  /// 1つ選んで表示する（osmCogitoの`CogitoSetupScreen._setKeywordOmakase`と
  /// 同じ方針）。チェックを一度外して入れ直すたびに新しい候補が選び直される。
  void _setKeywordOmakase(bool value) {
    setState(() {
      _keywordOmakase = value;
      if (value) {
        _keywordBeforeOmakase = _keywordController.text;
        _keywordController.text = pickLongArticleOmakaseTopic();
      } else {
        _keywordController.text = _keywordBeforeOmakase;
      }
    });
  }

  void _next() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    widget.onNext(
      LongArticleGenerationSettings(
        keyword: keyword,
        jlptLevel: _jlptLevel,
        looseness: _looseness,
        length: _length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: palette.textOnCardPrimary,
    );

    return Material(
      color: palette.scene,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              '長文読解'.tr(lang),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: palette.textOnScenePrimary,
              ),
            ),
            const SizedBox(height: 12),
            AiImportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('キーワード'.tr(lang), style: labelStyle),
                      const SizedBox(width: 8),
                      Flexible(
                        child: InkWell(
                          onTap: () => _setKeywordOmakase(!_keywordOmakase),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _keywordOmakase,
                                  onChanged: (value) =>
                                      _setKeywordOmakase(value ?? false),
                                  side: BorderSide(
                                    color: palette.textOnCardPrimary,
                                    width: 1.5,
                                  ),
                                  fillColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return palette.accentColor;
                                    }
                                    return Colors.transparent;
                                  }),
                                  checkColor: palette.onAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'おまかせ'.tr(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.textOnCardPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keywordController,
                    enabled: !_keywordOmakase,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: _keywordOmakase
                          ? palette.textOnCardSecondary
                          : palette.textOnCardPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: '長文読解_キーワード入力'.tr(lang),
                      hintStyle: TextStyle(color: palette.textOnCardSecondary),
                      filled: true,
                      fillColor: _keywordOmakase
                          ? palette.cardBorder
                          : palette.subpageBackground,
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('長文読解_JLPTレベル'.tr(lang), style: labelStyle),
                  const SizedBox(height: 8),
                  _SegmentedRow<LongArticleJlptLevel>(
                    value: _jlptLevel,
                    onChanged: (value) => setState(() => _jlptLevel = value),
                    segments: const [
                      (LongArticleJlptLevel.n1, 'N1'),
                      (LongArticleJlptLevel.n2, 'N2'),
                      (LongArticleJlptLevel.n3, 'N3'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('長文読解_文体の硬さ'.tr(lang), style: labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '長文読解_文体の硬さ_やわらかい'.tr(lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '長文読解_文体の硬さ_かたい'.tr(lang),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _looseness.sliderValue.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${_looseness.sliderValue}',
                    activeColor: palette.accentColor,
                    onChanged: (value) => setState(() {
                      _looseness =
                          LongArticleLooseness.values[value.round() - 1];
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('長文読解_文章の長さ'.tr(lang), style: labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '長文読解_文字数表示'.trFmt(lang, ['200']),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '長文読解_文字数表示'.trFmt(lang, ['1000']),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _length.sliderValue.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '長文読解_文字数表示'.trFmt(lang, [
                      '${_length.targetCharacterCount}',
                    ]),
                    activeColor: palette.accentColor,
                    onChanged: (value) => setState(() {
                      _length = LongArticleLength.values[value.round() - 1];
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canNext ? _next : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accentColor,
                        foregroundColor: palette.onAccent,
                        disabledBackgroundColor: palette.cardBorder,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '開始する'.tr(lang),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// N1/N2/N3のような、少数の等幅選択肢向け連結ピル行
/// （`vocabulary_sheet_form.dart`の`_LevelSegmentedRow`と同じ見た目）。
class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.value,
    required this.onChanged,
    required this.segments,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> segments;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) Container(width: 1, color: palette.cardBorder),
            Expanded(
              child: _Segment(
                label: segments[i].$2,
                selected: value == segments[i].$1,
                onTap: () => onChanged(segments[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
                  fontSize: 14,
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
