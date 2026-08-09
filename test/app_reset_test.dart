import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/services/app_reset.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  test('全データ初期化で設定とiOS/Androidの残存録音を削除する', () async {
    final originalProvider = PathProviderPlatform.instance;
    final directory = await Directory.systemTemp.createTemp(
      'osm_gradus_reset_',
    );
    addTearDown(() async {
      PathProviderPlatform.instance = originalProvider;
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    PathProviderPlatform.instance = _FakePathProvider(directory.path);

    final iosRecording = File('${directory.path}/layer4_recording.m4a');
    final androidRecording = File('${directory.path}/layer4_recording.wav');
    await iosRecording.writeAsString('audio');
    await androidRecording.writeAsString('audio');
    SharedPreferences.setMockInitialValues({'saved': true});

    await AppReset.resetToFactoryDefaults();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(await iosRecording.exists(), isFalse);
    expect(await androidRecording.exists(), isFalse);
  });
}
