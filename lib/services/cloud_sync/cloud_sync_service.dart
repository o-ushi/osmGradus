import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_preferences.dart';
import 'icloud_bridge.dart';

/// iCloud同期の状態（osmNichinichiの`CloudSyncStatus`と同じ）。
enum CloudSyncStatus { idle, uploading, downloading, unavailable, error }

/// 同期のエラーの種類。
enum CloudSyncError {
  /// 同期データがKVSの上限（1値1MB）を超えた。送らない。
  tooLarge,

  /// iCloudとのやり取り・データの検証に失敗した。
  failed,
}

/// 1キー分の値。`[型, 値]`（型は b/i/d/s/l）でSharedPreferencesの型を保つ。
typedef CloudSnapshot = Map<String, List<Object?>>;

/// 最後に両端末で揃った内容（3方向マージの基準）の保存先（テストでは差し替える）。
abstract interface class CloudSyncBaseStore {
  Future<CloudSnapshot?> read();

  Future<void> write(CloudSnapshot snapshot);
}

/// [CloudSyncBaseStore]をアプリ専用領域のJSONファイルに置く。
/// SharedPreferencesに置くと、同期データの倍の大きさがUserDefaultsに乗るため分ける。
class FileCloudSyncBaseStore implements CloudSyncBaseStore {
  static const fileName = 'cloud_sync_base.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<CloudSnapshot?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return CloudSyncService.decodeSnapshot(
        jsonDecode(await file.readAsString()),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(CloudSnapshot snapshot) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot), flush: true);
  }
}

/// iCloudのKVSで学習データと設定を同期する（osmNichinichiの`CloudSyncService`と
/// 同じ入口・状態・設定画面の要素）。
///
/// osmGradusのデータはすべてSharedPreferencesにあるため、同期する中身は
/// 「端末ごとのキー（[isSyncedKey]）を除いたSharedPreferencesの全キー」とし、
/// gzip＋base64で1つの値にしてKVSへ置く。
///
/// - 取り込みはキー単位の3方向マージ（基準＝最後に揃った内容）。片方だけが
///   変えたキーはその値を採り、削除も相手に伝わる。両方が変えたキーは、
///   `id`付きのJSON配列・文字列の配列なら項目単位で同じ3方向マージをし、
///   それ以外はiCloud（後から書かれた方）を採る
/// - この端末が一度も同期していないときは基準を空とみなし、端末とiCloudの
///   両方の項目を残す（新規インストールの既定値でiCloudを上書きしない）
/// - KVSの初回ダウンロードが終わるまで、空の読みを「クラウドが空」とみなして送らない
/// - 記録の保存ごとの通知は無いので、前面に戻ったとき・背面へ回るとき・
///   前面にいる間の一定間隔・「今すぐ同期」で、基準から変わっていれば送る
class CloudSyncService extends ChangeNotifier with WidgetsBindingObserver {
  CloudSyncService({
    required this._prefs,
    required this._bridge,
    required this._baseStore,
    required this._onApplied,
  });

  static const enabledKey = 'cloudSync.enabled';
  static const lastSyncKey = 'cloudSync.lastSyncMs';

  /// 最後に取り込んだ／書いたKVSの時刻。端末の時計のずれに左右されないよう、
  /// 「新しいか」ではなく「前に見た時刻と違うか」で比べる。
  static const seenRemoteTimestampKey = 'cloudSync.seenRemoteTimestamp';

  /// KVSの1値の上限（osmNichinichiと同じく1,000,000バイト未満だけ送る）。
  static const maxBytes = 1000000;

  /// 前面にいる間に、変更を送るか確かめる間隔。
  static const periodicInterval = Duration(minutes: 1);

  static const _payloadPrefix = 'gz1:';
  static const _payloadVersion = 1;

  /// 端末ごとの設定（同期しない）。表示言語・案内の表示はosmNichinichiと同じく
  /// 端末ごと。Podcastの再生中エピソード・開いている番組も端末の画面の状態。
  static const _deviceLocalKeys = {
    AppPreferences.languageKey,
    AppPreferences.showStartupScreenKey,
    AppPreferences.showUsageScreenKey,
    'podcast.lastPlayingEpisodeAudioUrl',
    'podcast.expandedShowIds',
  };

  /// 同期しないキーの接頭辞。同期自身の状態、開発者向け、音声送信の同意
  /// （端末で確認する）。Podcastのエピソード一覧（再生位置・再生済み・★）は
  /// osmPodと同じく同期する。
  static const _deviceLocalPrefixes = [
    'cloudSync.',
    'dev.',
    'osmGradus.privacy.',
  ];

  static bool isSyncedKey(String key) =>
      !_deviceLocalKeys.contains(key) &&
      !_deviceLocalPrefixes.any(key.startsWith);

  final SharedPreferences _prefs;
  final ICloudBridge _bridge;
  final CloudSyncBaseStore _baseStore;

  /// 取り込んだ後に、値をメモリに持つサービスを読み直す。
  final Future<void> Function() _onApplied;

  CloudSyncStatus _status = CloudSyncStatus.idle;
  CloudSyncStatus get status => _status;

  CloudSyncError? _error;
  CloudSyncError? get error => _error;

  /// [CloudSyncError.tooLarge]のときの同期データのバイト数。
  int? _errorBytes;
  int? get errorBytes => _errorBytes;

  /// 最後に確かめたiCloudのサインイン状態（まだならnull）。
  bool? _icloudAvailable;
  bool? get icloudAvailable => _icloudAvailable;

  bool _running = false;

  bool get isWorking =>
      _status == CloudSyncStatus.uploading ||
      _status == CloudSyncStatus.downloading;

  Timer? _periodic;

  /// 読み込み済みの基準（null＝まだファイルを読んでいない）。
  CloudSnapshot? _base;

  bool get isEnabled => _prefs.getBool(enabledKey) ?? false;

  /// オンにしたらすぐ1回同期する。オフでは送らない・受けない。
  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(enabledKey, value);
    if (!value) _setStatus(CloudSyncStatus.idle);
    notifyListeners();
    if (value) await manualSync();
  }

  DateTime? get lastSyncDate {
    final ms = _prefs.getInt(lastSyncKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// この端末がiCloudとの同期を一度も終えていないか（新規インストール・初期化後）。
  bool get _neverSynced => !_prefs.containsKey(lastSyncKey);

  /// 起動時に1回呼ぶ（main、iOSのみ）。他の端末からの変更と、前面に戻ったとき・
  /// 背面へ回るときの同期を始める。
  Future<void> attach() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      await _bridge.startObserving(() => unawaited(sync()));
    } on Exception catch (e) {
      debugPrint('osm_gradus: iCloud observe failed: $e');
    }
    _startPeriodic();
    await sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startPeriodic();
        unawaited(sync());
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _periodic?.cancel();
        // 背面に回る前に、この端末の変更を送っておく。
        unawaited(sync());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _startPeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(periodicInterval, (_) => unawaited(sync()));
  }

  @override
  void dispose() {
    _periodic?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 設定の「今すぐ同期」。
  Future<void> manualSync() => sync();

  /// iCloudに変更があれば取り込み、この端末に変更があれば送る。
  Future<void> sync() async {
    if (!isEnabled || _running) return;
    _running = true;
    try {
      await _exchange();
    } finally {
      _running = false;
    }
  }

  Future<void> _exchange() async {
    if (!await _checkAvailable()) return;
    final local = snapshotOf(_prefs);
    final ({String? data, double timestamp}) remote;
    try {
      remote = await _bridge.read();
    } on Exception catch (e) {
      debugPrint('osm_gradus: iCloud read failed: $e');
      _setStatus(CloudSyncStatus.error, error: CloudSyncError.failed);
      return;
    }
    final neverSynced = _neverSynced;
    final remoteData = remote.data;
    final remoteHasData = remoteData != null && remoteData.isNotEmpty;
    final seen = _prefs.getDouble(seenRemoteTimestampKey);

    if (remoteHasData && (neverSynced || remote.timestamp != seen)) {
      await _download(remoteData, remote.timestamp, local, neverSynced);
      return;
    }
    // 初回ダウンロードの前の空は「クラウドが空」ではない。既定値を送らない。
    if (neverSynced && !remoteHasData && !await _initialSyncFinished()) {
      return;
    }
    final base = await _loadBase();
    if (neverSynced || _canonical(local) != _canonical(base)) {
      await _upload(local);
    }
  }

  Future<bool> _initialSyncFinished() async {
    try {
      return await _bridge.hasFinishedInitialSync();
    } on Exception {
      return false;
    }
  }

  Future<bool> _checkAvailable() async {
    bool ok;
    try {
      ok = await _bridge.isAvailable();
    } on Exception {
      ok = false;
    }
    _icloudAvailable = ok;
    if (!ok) _setStatus(CloudSyncStatus.unavailable);
    return ok;
  }

  void _setStatus(
    CloudSyncStatus status, {
    CloudSyncError? error,
    int? errorBytes,
  }) {
    _status = status;
    _error = error;
    _errorBytes = errorBytes;
    notifyListeners();
  }

  Future<CloudSnapshot> _loadBase() async =>
      _base ??= await _baseStore.read() ?? {};

  Future<void> _saveBase(CloudSnapshot snapshot) async {
    _base = snapshot;
    await _baseStore.write(snapshot);
  }

  // MARK: 送る

  Future<void> _upload(CloudSnapshot snapshot) async {
    _setStatus(CloudSyncStatus.uploading);
    if (await _write(snapshot)) _setStatus(CloudSyncStatus.idle);
  }

  /// [snapshot]をKVSへ書き、基準にする。上限超え・失敗はエラーにしてfalse。
  Future<bool> _write(CloudSnapshot snapshot) async {
    try {
      final payload = encodePayload(snapshot);
      final bytes = utf8.encode(payload).length;
      // 黙って切らずに、送らないでエラーにする。
      if (bytes >= maxBytes) {
        _setStatus(
          CloudSyncStatus.error,
          error: CloudSyncError.tooLarge,
          errorBytes: bytes,
        );
        return false;
      }
      final now = clock.now();
      final timestamp = now.millisecondsSinceEpoch / 1000;
      await _bridge.write(payload, timestamp);
      await _saveBase(snapshot);
      await _prefs.setDouble(seenRemoteTimestampKey, timestamp);
      await _prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
      return true;
    } on Exception catch (e) {
      debugPrint('osm_gradus: iCloud upload failed: $e');
      _setStatus(CloudSyncStatus.error, error: CloudSyncError.failed);
      return false;
    }
  }

  // MARK: 取り込む

  Future<void> _download(
    String data,
    double remoteTimestamp,
    CloudSnapshot local,
    bool neverSynced,
  ) async {
    _setStatus(CloudSyncStatus.downloading);
    final CloudSnapshot remote;
    try {
      remote = decodePayload(data);
    } on Object catch (e) {
      debugPrint('osm_gradus: iCloud payload invalid: $e');
      _setStatus(CloudSyncStatus.error, error: CloudSyncError.failed);
      return;
    }
    // 一度も同期していない端末の基準は空（両方の項目を残す）。
    final base = neverSynced ? <String, List<Object?>>{} : await _loadBase();
    final merged = mergeSnapshots(base: base, local: local, remote: remote);
    try {
      await _applyToPrefs(merged, local);
      if (_canonical(merged) != _canonical(remote)) {
        // この端末の変更が混ざった。相手にも渡す。
        if (!await _write(merged)) return;
      } else {
        await _saveBase(merged);
        await _prefs.setDouble(seenRemoteTimestampKey, remoteTimestamp);
        await _prefs.setInt(lastSyncKey, clock.now().millisecondsSinceEpoch);
      }
      if (_canonical(merged) != _canonical(local)) await _onApplied();
      _setStatus(CloudSyncStatus.idle);
    } on Exception catch (e) {
      debugPrint('osm_gradus: iCloud download failed: $e');
      _setStatus(CloudSyncStatus.error, error: CloudSyncError.failed);
    }
  }

  /// [merged]になるよう、[local]から変わったキーだけを書き換える。
  Future<void> _applyToPrefs(CloudSnapshot merged, CloudSnapshot local) async {
    for (final key in local.keys) {
      if (!merged.containsKey(key)) await _prefs.remove(key);
    }
    for (final MapEntry(:key, :value) in merged.entries) {
      if (jsonEncode(value) == jsonEncode(local[key])) continue;
      final raw = value.length == 2 ? value[1] : null;
      switch (value.first) {
        case 'b' when raw is bool:
          await _prefs.setBool(key, raw);
        case 'i' when raw is num:
          await _prefs.setInt(key, raw.toInt());
        case 'd' when raw is num:
          await _prefs.setDouble(key, raw.toDouble());
        case 's' when raw is String:
          await _prefs.setString(key, raw);
        case 'l' when raw is List:
          await _prefs.setStringList(key, raw.whereType<String>().toList());
      }
    }
  }

  // MARK: 中身の形

  /// 同期するキー（[isSyncedKey]）の今の値。
  static CloudSnapshot snapshotOf(SharedPreferences prefs) {
    final result = <String, List<Object?>>{};
    for (final key in prefs.getKeys()) {
      if (!isSyncedKey(key)) continue;
      final value = prefs.get(key);
      final tagged = switch (value) {
        bool() => ['b', value],
        int() => ['i', value],
        double() => ['d', value],
        String() => ['s', value],
        List() => ['l', value.whereType<String>().toList()],
        _ => null,
      };
      if (tagged != null) result[key] = tagged;
    }
    return result;
  }

  /// KVSに置く文字列（`gz1:` ＋ gzipしたJSONのbase64）。
  static String encodePayload(CloudSnapshot snapshot) {
    final json = jsonEncode({'version': _payloadVersion, 'prefs': snapshot});
    return '$_payloadPrefix${base64Encode(gzip.encode(utf8.encode(json)))}';
  }

  static CloudSnapshot decodePayload(String data) {
    if (!data.startsWith(_payloadPrefix)) {
      throw const FormatException('unknown iCloud payload');
    }
    final bytes = gzip.decode(
      base64Decode(data.substring(_payloadPrefix.length)),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('invalid payload');
    return decodeSnapshot(decoded['prefs']);
  }

  static CloudSnapshot decodeSnapshot(Object? raw) {
    if (raw is! Map) throw const FormatException('invalid snapshot');
    return {
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is List && value.length == 2 && value.first is String)
          '$key': List<Object?>.from(value),
    };
  }

  static String _canonical(CloudSnapshot snapshot) {
    final keys = snapshot.keys.toList()..sort();
    return jsonEncode([
      for (final key in keys) [key, snapshot[key]],
    ]);
  }

  // MARK: マージ

  /// キー単位の3方向マージ。値がnull（無い）の結果はキーごと消す。
  @visibleForTesting
  static CloudSnapshot mergeSnapshots({
    required CloudSnapshot base,
    required CloudSnapshot local,
    required CloudSnapshot remote,
  }) {
    final result = <String, List<Object?>>{};
    for (final key in {...local.keys, ...remote.keys}) {
      final merged = _mergeValue(base[key], local[key], remote[key]);
      if (merged != null) result[key] = merged;
    }
    return result;
  }

  static List<Object?>? _mergeValue(
    List<Object?>? base,
    List<Object?>? local,
    List<Object?>? remote,
  ) {
    final b = jsonEncode(base);
    final l = jsonEncode(local);
    final r = jsonEncode(remote);
    if (l == r || r == b) return local;
    if (l == b) return remote;
    // 両方が変えた。
    if (local == null || remote == null) return local ?? remote;
    return _mergeItems(base, local, remote) ?? remote;
  }

  /// 配列の値を項目単位で3方向マージする。項目を見分けられない値はnull。
  /// 並びは端末の順で、iCloudだけにある項目を後ろに足す。
  static List<Object?>? _mergeItems(
    List<Object?>? base,
    List<Object?> local,
    List<Object?> remote,
  ) {
    final type = local.first;
    if (type != remote.first || (type != 's' && type != 'l')) return null;
    final l = _keyedItems(local);
    final r = _keyedItems(remote);
    if (l == null || r == null) return null;
    final b =
        (base != null && base.first == type ? _keyedItems(base) : null) ??
        <String, Object?>{};
    final items = <Object?>[];
    for (final key in {...l.keys, ...r.keys}) {
      final lv = jsonEncode(l[key]);
      final rv = jsonEncode(r[key]);
      final bv = jsonEncode(b[key]);
      final Object? item;
      if (lv == rv || rv == bv) {
        item = l[key];
      } else if (lv == bv) {
        item = r[key];
      } else {
        // 両方が変えた項目。消した側より変えた側を残す。
        item = _mergeBothChangedItem(l[key], r[key]) ?? r[key] ?? l[key];
      }
      if (item != null) items.add(item);
    }
    return type == 's' ? ['s', jsonEncode(items)] : ['l', items];
  }

  /// 両端末が同じ項目を変えたとき。Podcastのエピソード（`audioUrl`と
  /// `playbackPositionMs`を持つ）は、バックアップのインポートと同じく再生位置を
  /// 後退させず、再生済み・★はどちらかで付いていれば残す。それ以外はnull
  /// （呼び出し側でiCloudを採る）。
  static Object? _mergeBothChangedItem(Object? local, Object? remote) {
    final l = _asMap(local);
    final r = _asMap(remote);
    if (l == null || r == null) return null;
    if (l['audioUrl'] == null || !l.containsKey('playbackPositionMs')) {
      return null;
    }
    final lPos = (l['playbackPositionMs'] as num?)?.toInt() ?? 0;
    final rPos = (r['playbackPositionMs'] as num?)?.toInt() ?? 0;
    final merged = {
      ...r,
      'playbackPositionMs': lPos > rPos ? lPos : rPos,
      'isPlayed': l['isPlayed'] == true || r['isPlayed'] == true,
      'isFavorite': l['isFavorite'] == true || r['isFavorite'] == true,
      'isNew': l['isNew'] == true && r['isNew'] == true,
    };
    // 元の形（JSON文字列の配列の要素か、JSON配列の要素か）に戻す。
    return remote is String ? jsonEncode(merged) : merged;
  }

  /// 項目がオブジェクトならMapで返す（JSON文字列のオブジェクトも読む）。
  static Map<String, Object?>? _asMap(Object? item) {
    if (item is Map) return Map<String, Object?>.from(item);
    if (item is String && item.startsWith('{')) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) return Map<String, Object?>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// 項目の見分け方: `id`、無ければ`audioUrl`（Podcastのエピソード）。
  /// オブジェクトでない文字列はその文字列そのもの。
  /// Podcastのエピソード一覧は、1話ずつJSON文字列にした文字列の配列で保存されて
  /// いるので、文字列の中のオブジェクトも読んで見分ける（再生位置が変わっても同じ話）。
  /// 重複や見分けられない項目があればnull。
  static Map<String, Object?>? _keyedItems(List<Object?> tagged) {
    final raw = tagged.length == 2 ? tagged[1] : null;
    Object? list = raw;
    if (tagged.first == 's') {
      if (raw is! String || !raw.trimLeft().startsWith('[')) return null;
      try {
        list = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    }
    if (list is! List) return null;
    final result = <String, Object?>{};
    for (final item in list) {
      final key = switch (_asMap(item)) {
        {'id': final Object id} => 'id:$id',
        {'audioUrl': final Object url} => 'url:$url',
        null when item is String => 's:$item',
        _ => null,
      };
      if (key == null || result.containsKey(key)) return null;
      result[key] = item;
    }
    return result;
  }
}
