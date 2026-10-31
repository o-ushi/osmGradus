import 'package:flutter/services.dart';

/// iCloud（NSUbiquitousKeyValueStore）への出入り口（テストでは差し替える）。
///
/// osmNichinichiの`ICloudBridge`のうち、写真（iCloud Documents）を除いた部分。
/// iOS側の実装は ios/Runner/AppDelegate.swift の ICloudSyncChannel。
abstract interface class ICloudBridge {
  /// iCloudにサインイン済みか。
  Future<bool> isAvailable();

  /// KVSの同期データと、それを書いた時刻（1970年からの秒。無ければ0）。
  Future<({String? data, double timestamp})> read();

  /// KVSに同期データと時刻を書く。
  Future<void> write(String data, double timestamp);

  /// 他の端末からの変更の通知を受け始める。
  Future<void> startObserving(void Function() onExternalChange);

  /// この端末のKVSが、iCloudからの初回ダウンロードを終えたか。
  ///
  /// 終わる前の空の読みは「クラウドに何も無い」とは限らない。新規インストールが
  /// 既定の設定を送って、既存のiCloudを上書きしないために使う。
  Future<bool> hasFinishedInitialSync();
}

/// MethodChannel `com.osamushikubo.osm_gradus/icloud` でiOSのKVSを使う。
class MethodChannelICloudBridge implements ICloudBridge {
  MethodChannelICloudBridge([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.osamushikubo.osm_gradus/icloud';

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<({String? data, double timestamp})> read() async {
    final result = await _channel.invokeMapMethod<String, Object?>('read');
    return (
      data: result?['data'] as String?,
      timestamp: (result?['timestamp'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> write(String data, double timestamp) => _channel
      .invokeMethod<void>('write', {'data': data, 'timestamp': timestamp});

  @override
  Future<void> startObserving(void Function() onExternalChange) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'externalChange') onExternalChange();
    });
    await _channel.invokeMethod<void>('startObserving');
  }

  @override
  Future<bool> hasFinishedInitialSync() async =>
      await _channel.invokeMethod<bool>('hasFinishedInitialSync') ?? false;
}
