import 'package:shared_preferences/shared_preferences.dart';

/// 開発者モードの自己評価キャリブレーション（[JsstCalibrationService]）の
/// 補正係数・学習回数を永続化する。osmWashabeの`AppPreferences`が持つ
/// calibrationBias/calibrationSampleCountに相当する部分のみを切り出した
/// 軽量版。
class JsstCalibrationPreferences {
  static const _biasKey = 'layer4.calibration.bias';
  static const _sampleCountKey = 'layer4.calibration.sampleCount';

  SharedPreferences? _prefs;

  double _bias = 0.0;
  int _sampleCount = 0;

  double get bias => _bias;
  int get sampleCount => _sampleCount;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _bias = _prefs?.getDouble(_biasKey) ?? 0.0;
    _sampleCount = _prefs?.getInt(_sampleCountKey) ?? 0;
  }

  Future<void> update({required double bias, required int sampleCount}) async {
    _bias = bias;
    _sampleCount = sampleCount;
    await _prefs?.setDouble(_biasKey, bias);
    await _prefs?.setInt(_sampleCountKey, sampleCount);
  }

  Future<void> clear() async {
    _bias = 0.0;
    _sampleCount = 0;
    await _prefs?.remove(_biasKey);
    await _prefs?.remove(_sampleCountKey);
  }
}
