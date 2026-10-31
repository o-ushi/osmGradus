/// レイヤーⅣ1ラウンド分のPREP★・的中度★（Chrome AIの回答、osmCogitoの
/// `CogitoEvaluationResult`の移植）。
class PrepHitEvaluation {
  const PrepHitEvaluation({
    required this.prepStars,
    required this.hitStars,
    this.prepAdvice,
    this.hitAdvice,
    this.modelAnswer,
    this.modelAnswerRomaji,
    this.modelAnswerVi,
  });

  final int prepStars;
  final int hitStars;

  /// PREPへの一言アドバイス。AIが返さなかった場合はnull。
  final String? prepAdvice;

  /// 的中度への一言アドバイス。AIが返さなかった場合はnull。
  final String? hitAdvice;

  /// 発話を自然な日本語に直した模範回答。AIが返さなかった場合はnull。
  final String? modelAnswer;

  /// [modelAnswer]のローマ字。AIが返さなかった場合はnull。
  final String? modelAnswerRomaji;

  /// [modelAnswer]のベトナム語訳。AIが返さなかった場合はnull。
  final String? modelAnswerVi;
}
