/// osmWashabeの `SituationPrompt`（状況＋条件のペア）をそのまま移植。
class SituationPrompt {
  const SituationPrompt({required this.situation, required this.condition});

  final String situation;
  final String condition;
}
