import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/services/cloud_sync/cloud_sync_service.dart';
import 'package:osm_gradus/services/cloud_sync/icloud_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBridge implements ICloudBridge {
  bool available = true;
  bool initialSyncFinished = true;
  String? data;
  double timestamp = 0;
  int writes = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<({String? data, double timestamp})> read() async =>
      (data: data, timestamp: timestamp);

  @override
  Future<void> write(String data, double timestamp) async {
    this.data = data;
    this.timestamp = timestamp;
    writes++;
  }

  @override
  Future<void> startObserving(void Function() onExternalChange) async {}

  @override
  Future<bool> hasFinishedInitialSync() async => initialSyncFinished;
}

class _MemoryBaseStore implements CloudSyncBaseStore {
  CloudSnapshot? value;

  @override
  Future<CloudSnapshot?> read() async => value;

  @override
  Future<void> write(CloudSnapshot snapshot) async => value = snapshot;
}

/// 1台分（同じプロセスでは SharedPreferences が1つなので、端末の中身を差し替えて使う）。
class _Device {
  _Device(this.bridge);

  final _FakeBridge bridge;
  final base = _MemoryBaseStore();
  Map<String, Object> values = {};
  int applied = 0;

  Future<CloudSyncService> open() async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return CloudSyncService(
      prefs: prefs,
      bridge: bridge,
      baseStore: base,
      onApplied: () async => applied++,
    );
  }

  Future<void> close() async {
    final prefs = await SharedPreferences.getInstance();
    values = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeSnapshots', () {
    test('片方だけが変えたキーはその値、削除も伝わる', () {
      final merged = CloudSyncService.mergeSnapshots(
        base: {
          'a': ['i', 1],
          'b': ['s', 'x'],
          'c': ['b', true],
        },
        local: {
          'a': ['i', 2],
          'b': ['s', 'x'],
          'c': ['b', true],
        },
        remote: {
          'a': ['i', 1],
          'b': ['s', 'y'],
        },
      );
      expect(merged, {
        'a': ['i', 2],
        'b': ['s', 'y'],
      });
    });

    test('両方が変えたidの配列は項目単位でマージし、消した項目は戻さない', () {
      String list(List<Map<String, Object>> items) =>
          '[${items.map((e) => '{"id":"${e['id']}","v":${e['v']}}').join(',')}]';
      final merged = CloudSyncService.mergeSnapshots(
        base: {
          'k': [
            's',
            list([
              {'id': '1', 'v': 1},
              {'id': '2', 'v': 1},
            ]),
          ],
        },
        // 端末: 2を消し、3を足した
        local: {
          'k': [
            's',
            list([
              {'id': '1', 'v': 1},
              {'id': '3', 'v': 1},
            ]),
          ],
        },
        // iCloud: 1を書き換え、4を足した
        remote: {
          'k': [
            's',
            list([
              {'id': '1', 'v': 2},
              {'id': '2', 'v': 1},
              {'id': '4', 'v': 1},
            ]),
          ],
        },
      );
      expect(merged['k'], [
        's',
        list([
          {'id': '1', 'v': 2},
          {'id': '3', 'v': 1},
          {'id': '4', 'v': 1},
        ]),
      ]);
    });

    test('初回（基準が空）は両方の文字列配列を残す', () {
      final merged = CloudSyncService.mergeSnapshots(
        base: {},
        local: {
          't': [
            'l',
            ['a', 'b'],
          ],
        },
        remote: {
          't': [
            'l',
            ['b', 'c'],
          ],
        },
      );
      expect(merged['t'], [
        'l',
        ['a', 'b', 'c'],
      ]);
    });

    test('両方が変えた値（配列以外）はiCloudを採る', () {
      final merged = CloudSyncService.mergeSnapshots(
        base: {
          'r': ['d', 1.0],
        },
        local: {
          'r': ['d', 1.2],
        },
        remote: {
          'r': ['d', 0.8],
        },
      );
      expect(merged['r'], ['d', 0.8]);
    });
  });

  group('Podcastのエピソード', () {
    String ep(
      String url, {
      int pos = 0,
      bool played = false,
      bool fav = false,
    }) =>
        '{"showId":"s","audioUrl":"$url","playbackPositionMs":$pos,'
        '"isPlayed":$played,"isNew":false,"isFavorite":$fav}';

    test('片方で再生位置が進んだ話は、同じ話として置き換わる（重複しない）', () {
      final merged = CloudSyncService.mergeSnapshots(
        base: {
          'podcast.episodes.s': [
            'l',
            [ep('a'), ep('b')],
          ],
        },
        local: {
          'podcast.episodes.s': [
            'l',
            [ep('a', pos: 5000), ep('b')],
          ],
        },
        // iCloud: 新しい話cが増えた
        remote: {
          'podcast.episodes.s': [
            'l',
            [ep('c'), ep('a'), ep('b')],
          ],
        },
      );
      expect(merged['podcast.episodes.s'], [
        'l',
        [ep('a', pos: 5000), ep('b'), ep('c')],
      ]);
    });

    test('両方で同じ話を変えたら、再生位置は後退させず、再生済み・★は残す', () {
      final merged = CloudSyncService.mergeSnapshots(
        base: {
          'podcast.episodes.s': [
            'l',
            [ep('a')],
          ],
        },
        local: {
          'podcast.episodes.s': [
            'l',
            [ep('a', pos: 9000, fav: true)],
          ],
        },
        remote: {
          'podcast.episodes.s': [
            'l',
            [ep('a', pos: 3000, played: true)],
          ],
        },
      );
      expect(merged['podcast.episodes.s'], [
        'l',
        [ep('a', pos: 9000, played: true, fav: true)],
      ]);
    });
  });

  test('端末ごとのキーは同期しない', () {
    expect(CloudSyncService.isSyncedKey('osmGradus.language'), isFalse);
    expect(
      CloudSyncService.isSyncedKey('osmGradus.showStartupScreen'),
      isFalse,
    );
    expect(CloudSyncService.isSyncedKey('cloudSync.enabled'), isFalse);
    expect(
      CloudSyncService.isSyncedKey('osmGradus.privacy.speechConsentVersion'),
      isFalse,
    );
    expect(CloudSyncService.isSyncedKey('podcast.episodes.abc'), isTrue);
    expect(
      CloudSyncService.isSyncedKey('podcast.lastPlayingEpisodeAudioUrl'),
      isFalse,
    );
    expect(CloudSyncService.isSyncedKey('vocabulary.entries'), isTrue);
    expect(CloudSyncService.isSyncedKey('podcast.registeredShows'), isTrue);
  });

  test('payloadは往復で型を保つ', () {
    final snapshot = <String, List<Object?>>{
      'b': ['b', true],
      'i': ['i', 3],
      'd': ['d', 1.5],
      's': ['s', 'あ'],
      'l': [
        'l',
        ['x', 'y'],
      ],
    };
    expect(
      CloudSyncService.decodePayload(CloudSyncService.encodePayload(snapshot)),
      snapshot,
    );
  });

  test('同期オフでは送らない・受けない', () async {
    final bridge = _FakeBridge();
    final device = _Device(bridge)..values = {'vocabulary.entries': '[]'};
    final sync = await device.open();
    await sync.sync();
    expect(bridge.writes, 0);
  });

  test('iCloud未サインインなら送らず、状態をunavailableにする', () async {
    final bridge = _FakeBridge()..available = false;
    final device = _Device(bridge)
      ..values = {CloudSyncService.enabledKey: true};
    final sync = await device.open();
    await sync.sync();
    expect(bridge.writes, 0);
    expect(sync.status, CloudSyncStatus.unavailable);
  });

  test('初回ダウンロード前の空のiCloudには送らない', () async {
    final bridge = _FakeBridge()..initialSyncFinished = false;
    final device = _Device(bridge)
      ..values = {CloudSyncService.enabledKey: true, 'x': 'local'};
    final sync = await device.open();
    await sync.sync();
    expect(bridge.writes, 0);
  });

  test('上限を超えるデータは送らずエラーにする', () async {
    final bridge = _FakeBridge();
    // gzipで縮まないよう、乱数に近い文字列にする。
    final noise = List.generate(
      900000,
      (i) => String.fromCharCode(0x4E00 + (i * 7919) % 20000),
    ).join();
    final device = _Device(bridge)
      ..values = {CloudSyncService.enabledKey: true, 'big': noise};
    final sync = await device.open();
    await sync.sync();
    expect(bridge.writes, 0);
    expect(sync.error, CloudSyncError.tooLarge);
  });

  test('2台: 追加・削除・言語は端末ごと、が相手に伝わる', () async {
    final bridge = _FakeBridge();
    final a = _Device(bridge)
      ..values = {
        CloudSyncService.enabledKey: true,
        'osmGradus.language': 'ja',
        'vocabulary.entries': '[{"id":"1","w":"猫"}]',
        'topics.imported.general': <String>['お題A'],
      };
    final b = _Device(bridge)
      ..values = {
        CloudSyncService.enabledKey: true,
        'osmGradus.language': 'vi',
        'vocabulary.entries': '[{"id":"2","w":"犬"}]',
      };

    // A が最初に送る
    var sync = await a.open();
    await sync.sync();
    await a.close();
    expect(bridge.writes, 1);

    // B は初回: 両方の単語を残して送り返す
    sync = await b.open();
    await sync.sync();
    await b.close();
    expect(b.values['osmGradus.language'], 'vi');
    expect(
      b.values['vocabulary.entries'],
      '[{"id":"2","w":"犬"},{"id":"1","w":"猫"}]',
    );
    expect(b.values['topics.imported.general'], ['お題A']);
    expect(bridge.writes, 2);

    // A が取り込む
    sync = await a.open();
    await sync.sync();
    await a.close();
    expect(a.values['osmGradus.language'], 'ja');
    expect(
      a.values['vocabulary.entries'],
      '[{"id":"2","w":"犬"},{"id":"1","w":"猫"}]',
    );
    expect(a.applied, 1);

    // A で「猫」を消してお題を消す → B でも消える（古いBから復活しない）
    a.values['vocabulary.entries'] = '[{"id":"2","w":"犬"}]';
    a.values.remove('topics.imported.general');
    sync = await a.open();
    await sync.sync();
    await a.close();

    sync = await b.open();
    await sync.sync();
    await b.close();
    expect(b.values['vocabulary.entries'], '[{"id":"2","w":"犬"}]');
    expect(b.values.containsKey('topics.imported.general'), isFalse);

    // 変わっていなければ送らない
    final before = bridge.writes;
    sync = await b.open();
    await sync.sync();
    expect(bridge.writes, before);
  });
}
