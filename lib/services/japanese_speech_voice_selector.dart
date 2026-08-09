/// osmWashabeの`japanese_speech_voice_selector.dart`の移植。
class SpeechVoiceInfo {
  const SpeechVoiceInfo({
    required this.name,
    required this.qualityLabel,
    required this.isHighQuality,
  });

  final String name;
  final String qualityLabel;
  final bool isHighQuality;
}

enum SpeechVoiceGender {
  male('男性の声'),
  female('女性の声'),
  random('ランダム');

  const SpeechVoiceGender(this.rawValue);
  final String rawValue;

  static SpeechVoiceGender fromStored(String raw) {
    return SpeechVoiceGender.values.firstWhere(
      (g) => g.rawValue == raw,
      orElse: () => SpeechVoiceGender.female,
    );
  }
}
