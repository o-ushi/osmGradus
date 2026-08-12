import 'dart:math';

final _idRandom = Random();

/// 「25マス思考」のテーマ1つ（ボードの行に対応。旧`ThinkingNeta`）。
class ThinkingTheme {
  const ThinkingTheme({required this.id, required this.name});

  final String id;
  final String name;

  factory ThinkingTheme.create(String name) => ThinkingTheme(
    id: 'tm_theme_${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
    name: name,
  );

  ThinkingTheme copyWith({String? name}) =>
      ThinkingTheme(id: id, name: name ?? this.name);

  /// 旧`tm_neta_*`形式のIDもそのまま読める（IDの中身に意味は無いため
  /// マイグレーション不要。[fromJson]は値をそのまま使う）。
  factory ThinkingTheme.fromJson(Map<String, dynamic> json) => ThinkingTheme(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
