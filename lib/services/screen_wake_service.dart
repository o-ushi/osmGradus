import 'package:wakelock_plus/wakelock_plus.dart';

/// 画面の自動スリープ抑止（Wakelock）を「理由」単位で管理する。
///
/// osmWashabeは`WakelockPlus.enable()`をアプリ起動時に1回呼ぶだけで、
/// アプリが開いている間ずっと画面が消えない作りだった。osmGradusは
/// レイヤーⅠでPodcastをバックグラウンド的に聴く時間が長いため、
/// 常時点灯だとバッテリー消費が問題になる。そのため「読み上げ中」
/// 「カウントダウン中」など、画面を見ている必要がある理由がある間だけ
/// 点灯を維持し、それ以外（Podcast再生中・アイドル中など）は通常どおり
/// 自動スリープさせる。
///
/// 複数の理由が同時に成立しうる（例: 15+60秒モードで「それでは、答えて
/// ください」を読み上げている間は「読み上げ」と「カウントダウン」の両方が
/// 成立している）ため、単純なbool管理ではなく理由の集合で数える。
/// どれか1つでも理由が残っていればWakelockはON、全て無くなったらOFFにする。
class ScreenWakeService {
  ScreenWakeService._();
  static final ScreenWakeService instance = ScreenWakeService._();

  final Set<String> _reasons = {};

  Future<void> acquire(String reason) async {
    final wasEmpty = _reasons.isEmpty;
    _reasons.add(reason);
    if (wasEmpty) {
      await WakelockPlus.enable();
    }
  }

  Future<void> release(String reason) async {
    if (_reasons.isEmpty) return;
    _reasons.remove(reason);
    if (_reasons.isEmpty) {
      await WakelockPlus.disable();
    }
  }
}
