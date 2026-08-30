import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/models/layer4_prompt_reveal_mode.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';

void main() {
  group('Layer4PromptRevealMode 永続化（Step 1）', () {
    test('既定値はタートル', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();

      expect(prefs.layer4PromptRevealMode, Layer4PromptRevealMode.turtle);
    });

    test('保存した値がAppPreferencesの読み戻しに反映される', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();

      prefs.layer4PromptRevealMode = Layer4PromptRevealMode.rapid;

      expect(prefs.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);
    });

    test('不正な保存値は既定値（タートル）にフォールバックする', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.layer4PromptRevealModeKey: 'unknown',
      });
      final prefs = await AppPreferences.load();

      expect(prefs.layer4PromptRevealMode, Layer4PromptRevealMode.turtle);
    });

    test('AppSettings経由の読み書きも永続化される（再起動後を模したロード）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      final settings = AppSettings(prefs);

      expect(settings.layer4PromptRevealMode, Layer4PromptRevealMode.turtle);

      settings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid;
      expect(settings.layer4PromptRevealMode, Layer4PromptRevealMode.rapid);

      // 再起動を模して同じSharedPreferencesから読み直す。
      final reloadedPrefs = await AppPreferences.load();
      expect(
        reloadedPrefs.layer4PromptRevealMode,
        Layer4PromptRevealMode.rapid,
      );
    });

    test('AppSettingsは値が変わらないときnotifyListenersしない', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      final settings = AppSettings(prefs);

      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.layer4PromptRevealMode = Layer4PromptRevealMode.turtle;
      expect(notifyCount, 0);

      settings.layer4PromptRevealMode = Layer4PromptRevealMode.rapid;
      expect(notifyCount, 1);
    });
  });
}
