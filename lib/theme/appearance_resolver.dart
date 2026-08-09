import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 背景色に対する読みやすい前景色を決めるコントラストヘルパー。
abstract final class AppearanceResolver {
  static const _readableDarkText = Color.fromRGBO(26, 26, 31, 1);
  static const _readableMutedText = Color.fromRGBO(97, 97, 107, 1);

  /// 背景色が「明るい」と判定するかどうか。
  /// FlutterのWCAG準拠の判定式（`ThemeData.estimateBrightnessForColor`）を使う。
  static bool isLightSurface(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.light;

  /// WCAG 2.x の相対輝度（0.0〜1.0）。
  static double relativeLuminance(Color color) {
    double linearize(double channel) {
      return channel <= 0.03928
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize(color.r);
    final g = linearize(color.g);
    final b = linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 2色間のコントラスト比（1.0〜21.0）。
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 背景色に対してコントラストが高い方のテキスト色（黒系 or 白）を返す。
  static Color primaryTextOn(Color fill) {
    const light = Colors.white;
    final darkRatio = contrastRatio(fill, _readableDarkText);
    final lightRatio = contrastRatio(fill, light);
    if ((darkRatio - lightRatio).abs() < 0.35) {
      return isLightSurface(fill) ? _readableDarkText : light;
    }
    return darkRatio >= lightRatio ? _readableDarkText : light;
  }

  /// 背景色に対して 3:1 以上のコントラストを持つ補助テキスト色を返す。
  static Color secondaryTextOn(Color fill) {
    final primary = primaryTextOn(fill);
    if (primary == Colors.white) {
      return Colors.white.withValues(alpha: 0.75);
    }
    return _readableMutedText;
  }

  /// 塗りつぶしボタン（アクセント色・レイヤー色など）の上に載せる文字・アイコン色。
  static Color onFill(Color fill) => primaryTextOn(fill);

  /// シーン背景上の輪郭線・アイコン色（非アクティブなピルボタン等）。
  static Color outlineOn(Color scene) => primaryTextOn(scene);
}
