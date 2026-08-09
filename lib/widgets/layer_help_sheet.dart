import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';

/// [LayerHelpSheet]の1行分。[text]の中の`{{icon}}`という文字列を[icon]の
/// アイコンに差し替えて描画する（プレースホルダーは1行につき最大1つ）。
/// [indent]をtrueにすると、見出し行の下にぶら下がる子項目として字下げする
/// （レイヤーⅤのモード説明のように、番号付き項目の下に複数行の補足を
/// 並べたいときに使う）。
class LayerHelpLine {
  const LayerHelpLine({required this.text, this.icon, this.indent = false});

  final String text;
  final IconData? icon;
  final bool indent;
}

/// 各レイヤー画面の「＋」を長押ししたときに表示する使い方シート。
/// [EpisodeSortSheet]と同じ、つまみ付きの角丸ボトムシートで統一する。
class LayerHelpSheet extends StatelessWidget {
  const LayerHelpSheet({super.key, required this.title, required this.lines});

  final String title;
  final List<LayerHelpLine> lines;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<LayerHelpLine> lines,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardFill,
      // レイヤーⅤ等、行数が多いレイヤーでは既定の高さ制限に収まらないため、
      // isScrollControlled+内側のスクロールで画面いっぱいまで広げられるようにする。
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LayerHelpSheet(title: title, lines: lines),
    );
  }

  /// [HelpScreen]と同じ tip キー列から、簡易な使い方シートを開く。
  static Future<void> showFromTipKeys(
    BuildContext context, {
    required String titleKey,
    required List<String> tipKeys,
    required String lang,
  }) {
    return show(
      context,
      title: titleKey.tr(lang),
      lines: [
        for (final key in tipKeys) LayerHelpLine(text: key.tr(lang)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                title,
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
                      for (final line in lines) _HelpLineView(line: line),
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

class _HelpLineView extends StatelessWidget {
  const _HelpLineView({required this.line});

  final LayerHelpLine line;

  /// 行頭の連番バッジ（1️⃣〜9️⃣、絵文字の合字）を検出する。
  static final RegExp _leadingNumberBadge = RegExp(
    '^[0-9]️⃣[ 　]*',
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final style = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: palette.textOnCardPrimary,
    );

    // 連番バッジ・アイコンをそのまま文中に混ぜて描画すると、折り返した
    // 2行目以降がその分の字下げを引き継がずインデント無しの左端まで
    // 戻ってしまう（Textには「行頭の装飾の後で字下げを保つ」機能がないため）。
    // 連番バッジ・アイコンを固定幅の先頭列としてRowで切り出し、残りの説明文
    // だけをExpandedで可変幅に折り返せば、2行目以降も自然に揃う。この列幅は
    // 実際の描画幅を都度測り直すため、設定でフォントサイズを変えても崩れない。
    final badgeMatch = _leadingNumberBadge.matchAsPrefix(line.text);
    final badge = badgeMatch?.group(0)?.trimRight();
    final rest = badgeMatch == null
        ? line.text
        : line.text.substring(badgeMatch.end);

    final children = <Widget>[
      if (badge != null) ...[
        Text(badge, style: style),
        const SizedBox(width: 6),
      ],
    ];

    if (line.icon == null) {
      children.add(Expanded(child: Text(rest, style: style)));
    } else {
      final parts = rest.split('{{icon}}');
      final before = parts.first;
      final after = parts.length > 1 ? parts.sublist(1).join('{{icon}}') : '';
      if (before.isNotEmpty) children.add(Text(before, style: style));
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: 2, top: 2),
          child: Icon(line.icon, size: 18, color: palette.textOnCardPrimary),
        ),
      );
      children.add(Expanded(child: Text(after, style: style)));
    }

    final body = badge == null && line.icon == null
        ? Text(line.text, style: style)
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);

    return Padding(
      padding: EdgeInsets.only(left: line.indent ? 24 : 0, bottom: 6),
      child: body,
    );
  }
}
