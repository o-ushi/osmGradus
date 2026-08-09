import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/services/privacy_consent_service.dart';
import 'package:osm_gradus/widgets/speech_processing_consent_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLauncher(
    WidgetTester tester,
    ValueChanged<bool> onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await SpeechProcessingConsentDialog.ensure(
                context,
                'ja',
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('拒否した場合は同意を保存せずfalseを返す', (tester) async {
    bool? result;
    await pumpLauncher(tester, (value) => result = value);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('録音音声の処理について'), findsOneWidget);
    await tester.tap(find.text('同意しない'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(await PrivacyConsentService.hasSpeechProcessingConsent(), isFalse);
  });

  testWidgets('同意した場合は保存してtrueを返す', (tester) async {
    bool? result;
    await pumpLauncher(tester, (value) => result = value);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意して続ける'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(await PrivacyConsentService.hasSpeechProcessingConsent(), isTrue);
  });
}
