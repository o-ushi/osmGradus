import 'package:flutter/material.dart';

import 'appearance_resolver.dart';

/// osmファミリー共通の固定カラーパレット。
///
/// シーン背景・カード枠・アクセントはデザインシステムとして固定。
/// ユーザー向けのテーマ／外観切り替えは持たない。
class AppPalette {
  const AppPalette({
    required this.scene,
    required this.subpageBackground,
    required this.cardFill,
    required this.cardBorder,
    required this.cardAccent,
    required this.accentColor,
    required this.onAccent,
    required this.textOnScenePrimary,
    required this.textOnSceneSecondary,
    required this.textOnSubpagePrimary,
    required this.textOnSubpageSecondary,
    required this.textOnCardPrimary,
    required this.textOnCardSecondary,
    required this.layerColors,
  });

  /// メイン画面（起動画面・レイヤー画面）の背景色。
  final Color scene;

  /// 設定・ヘルプなどサブ画面の背景色（iOS標準グレー）。
  final Color subpageBackground;

  /// シーン上に浮かぶカード（レイヤー選択タイル等）の塗り色。
  final Color cardFill;

  /// カードの枠線色。
  final Color cardBorder;

  /// カードのアクセントストライプ色。
  final Color cardAccent;

  /// ボタン等のメインアクセントカラー。
  final Color accentColor;

  /// [accentColor] で塗られた面の上に乗せる文字・アイコン色。
  final Color onAccent;

  /// [scene] の上に直接乗せる文字色。
  final Color textOnScenePrimary;
  final Color textOnSceneSecondary;

  /// [subpageBackground] の上に乗せる文字色。
  final Color textOnSubpagePrimary;
  final Color textOnSubpageSecondary;

  /// [cardFill] の上に乗せる文字色。
  final Color textOnCardPrimary;
  final Color textOnCardSecondary;

  /// レイヤーⅠ〜Ⅴに割り当てるアクセントカラー（先頭から順にⅠ, Ⅱ, Ⅲ, Ⅳ, Ⅴ）。
  final List<Color> layerColors;

  static const flatDefault = AppPalette(
    scene: Color(0xFF3D5993),
    subpageBackground: Color(0xFFF2F2F7),
    cardFill: Color(0xFFFFFAF2),
    cardBorder: Color(0xFFF5C799),
    cardAccent: Color(0xFFFF9933),
    accentColor: Color(0xFF007AFF),
    onAccent: Color(0xFFFFFFFF),
    textOnScenePrimary: Color(0xFFFFFFFF),
    textOnSceneSecondary: Color(0xB3FFFFFF),
    textOnSubpagePrimary: Color(0xFF1A1A1F),
    textOnSubpageSecondary: Color(0xFF61616B),
    textOnCardPrimary: Color(0xFF1A1A1F),
    textOnCardSecondary: Color(0xFF61616B),
    layerColors: kLayerColors,
  );
}

/// レイヤーⅠ〜Ⅴの固定イメージカラー。先頭から順にⅠ, Ⅱ, Ⅲ, Ⅳ, Ⅴ。
const List<Color> kLayerColors = [
  Color(0xFFFF3B30), // Ⅰ：赤
  Color(0xFF007AFF), // Ⅱ：青
  Color(0xFFFFCC00), // Ⅲ：黄
  Color(0xFFFA408C), // Ⅳ：ピンク
  Color(0xFF34C759), // Ⅴ：緑
];

class AppColors {
  AppColors._();

  /// アプリ全体で使う固定パレット。
  static const AppPalette current = AppPalette.flatDefault;
}

/// 任意の背景色に対する読みやすい前景色を [AppPalette] から取得する。
extension AppPaletteContrast on AppPalette {
  Color textOn(Color background) =>
      AppearanceResolver.primaryTextOn(background);

  Color mutedTextOn(Color background) =>
      AppearanceResolver.secondaryTextOn(background);

  Color onFill(Color fill) {
    // 赤（レイヤーⅠ）・ピンク（レイヤーⅣ）はWCAG輝度計算上は黒文字の方が
    // わずかに高コントラストと判定されるが、実際の見た目としては白文字の方が
    // 読みやすいため、常に白にする。
    if (fill == kLayerColors[0] || fill == kLayerColors[3]) {
      return Colors.white;
    }
    return AppearanceResolver.onFill(fill);
  }

  Color outlineOnScene(Color scene) => AppearanceResolver.outlineOn(scene);
}

/// osmGenkiの「貼り付け待ち」ボタン色（Chrome AI から戻ったあと）。
const Color kPasteReadyColor = Color(0xFF34C759);
