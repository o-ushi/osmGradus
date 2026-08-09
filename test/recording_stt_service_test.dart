import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/services/recording_stt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const captureChannel = MethodChannel(
    'com.osamushikubo.osm_gradus/speech_capture',
  );

  final calledMethods = <String>[];

  setUp(() {
    calledMethods.clear();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(captureChannel, (call) async {
          calledMethods.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(captureChannel, null);
  });

  // レイヤーⅠ単語テストのキーボード入力モードで「リセット」を押すと、録音して
  // いないのに RecordingSttService.cancel() がネイティブの
  // stopCapture/cancelRecording を呼んでしまい、iOS側でAVAudioSessionが
  // 無条件に非アクティブ化される副作用でソフトウェアキーボードだけが閉じて
  // しまう回帰があった（FocusNodeはフォーカス済みのままなので再表示されない）。
  // 録音中でなければネイティブ呼び出し自体を発生させないことを固定する。
  test(
    '録音していない状態でcancel()を呼んでもネイティブのstopCapture/cancelRecordingは呼ばれない',
    () async {
      final service = RecordingSttService();

      await service.cancel();

      expect(calledMethods, isEmpty);
    },
  );
}
