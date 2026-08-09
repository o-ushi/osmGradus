import 'package:flutter/foundation.dart';

/// 「結論」「理由」「例示」（PREP法）の進行段階。
enum PrepStage { conclusion, reason, example, done }

/// タイマー開始時（または初期状態）に「結論」から点滅を始め、タップするたびに
/// 次の段階へ進む。「例示」がタップされたら`done`になり、全て非点滅の白に戻る。
/// osmGradus独自の機能（osmWashabeには存在しない）。
class PrepStageController extends ChangeNotifier {
  PrepStage stage = PrepStage.conclusion;

  /// タイマー開始時に「結論」から点滅をやり直す。
  void start() {
    stage = PrepStage.conclusion;
    notifyListeners();
  }

  /// 点滅中の段階がタップされたときに次へ進める。
  void advance() {
    stage = switch (stage) {
      PrepStage.conclusion => PrepStage.reason,
      PrepStage.reason => PrepStage.example,
      PrepStage.example => PrepStage.done,
      PrepStage.done => PrepStage.done,
    };
    notifyListeners();
  }

  void reset() {
    stage = PrepStage.conclusion;
    notifyListeners();
  }
}
