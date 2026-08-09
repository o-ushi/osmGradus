/// レイヤーⅣ1ラウンド分のPREP★・的中度★（Chrome AIの回答、osmCogitoの
/// `CogitoEvaluationResult`の移植）。
class PrepHitEvaluation {
  const PrepHitEvaluation({
    required this.prepStars,
    required this.hitStars,
    this.prepAdvice,
    this.hitAdvice,
  });

  final int prepStars;
  final int hitStars;

  /// PREPへの一言アドバイス。AIが返さなかった場合はnull。
  final String? prepAdvice;

  /// 的中度への一言アドバイス。AIが返さなかった場合はnull。
  final String? hitAdvice;
}
