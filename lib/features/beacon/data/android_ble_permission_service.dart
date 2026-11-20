import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/ble_permission_service.dart';
import '../domain/ble_scan_models.dart';

/// Android MethodChannel implementation of [BlePermissionService].
final class MethodChannelBlePermissionService implements BlePermissionService {
  MethodChannelBlePermissionService({MethodChannel? channel, AppLogger? logger})
    : _channel = channel ?? const MethodChannel(_channelName),
      _logger = logger;

  static const String _channelName = 'at.fhtw.poi_map_android/ble_permissions';

  final MethodChannel _channel;
  final AppLogger? _logger;

  @override
  Future<BlePermissionStatus> checkPermission() async {
    return _invokePermissionCall('checkBlePermissions');
  }

  @override
  Future<BlePermissionStatus> requestPermission() async {
    return _invokePermissionCall('requestBlePermissions');
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openAppSettings');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      _logger?.warning(
        'BlePermissions',
        'Unable to open app settings for BLE permissions',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<BlePermissionStatus> _invokePermissionCall(String method) async {
    try {
      final raw = await _channel.invokeMethod<String>(method);
      return switch (raw) {
        'granted' => BlePermissionStatus.granted,
        'permanentlyDenied' => BlePermissionStatus.permanentlyDenied,
        'denied' => BlePermissionStatus.denied,
        _ => BlePermissionStatus.unsupported,
      };
    } on MissingPluginException {
      return BlePermissionStatus.unsupported;
    } on PlatformException catch (error, stackTrace) {
      _logger?.warning(
        'BlePermissions',
        'BLE permission check failed ($method)',
        error: error,
        stackTrace: stackTrace,
      );
      return BlePermissionStatus.denied;
    }
  }
}
