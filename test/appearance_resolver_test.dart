import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/theme/appearance_resolver.dart';

void main() {
  group('AppearanceResolver contrast', () {
    test('暗いシーン背景では白文字を選ぶ', () {
      const scene = Color.fromRGBO(61, 89, 147, 1);
      expect(AppearanceResolver.primaryTextOn(scene), Colors.white);
    });

    test('明るいシーン背景では黒文字を選ぶ', () {
      const scene = Color.fromRGBO(253, 252, 240, 1);
      expect(
        AppearanceResolver.primaryTextOn(scene),
        const Color.fromRGBO(26, 26, 31, 1),
      );
    });

    test('明るいサブページ背景では黒文字を選ぶ', () {
      const subpage = Color(0xFFF2F2F7);
      expect(
        AppearanceResolver.primaryTextOn(subpage),
        const Color.fromRGBO(26, 26, 31, 1),
      );
    });

    test('橙色のアクセントでは黒文字を選ぶ', () {
      const accent = Color.fromRGBO(255, 153, 51, 1);
      expect(
        AppearanceResolver.primaryTextOn(accent),
        const Color.fromRGBO(26, 26, 31, 1),
      );
    });

    test('コントラスト比は1より大きい', () {
      const a = Color.fromRGBO(61, 89, 147, 1);
      const b = Colors.white;
      expect(AppearanceResolver.contrastRatio(a, b), greaterThan(3));
    });
  });
}
