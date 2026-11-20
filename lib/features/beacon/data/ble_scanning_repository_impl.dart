import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/ble_permission_service.dart';
import '../domain/ble_scan_models.dart';
import '../domain/ble_scanning_repository.dart';
import 'ble_scan_data_source.dart';

/// Concrete BLE scanning repository with concurrency protection and error mapping.
final class BleScanningRepositoryImpl implements BleScanningRepository {
  BleScanningRepositoryImpl({
    required BleScanDataSource dataSource,
    required BlePermissionService permissionService,
    AppLogger? logger,
  }) : _dataSource = dataSource,
       _permissionService = permissionService,
       _logger = logger;

  final BleScanDataSource _dataSource;
  final BlePermissionService _permissionService;
  final AppLogger? _logger;

  Future<void>? _activeStartFuture;
  bool _disposed = false;

  @override
  Stream<BleAdapterState> get adapterStateStream => _dataSource.adapterState;

  @override
  Stream<List<BleRawScanResult>> get scanResultsStream =>
      _dataSource.scanResults;

  @override
  Stream<bool> get isScanningStream => _dataSource.isScanning;

  @override
  Future<bool> isSupported() async {
    try {
      return await _dataSource.isSupported();
    } catch (error, stackTrace) {
      _logger?.warning(
        'BleScan',
        'Failed to check BLE hardware support',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    final state = await _dataSource.getCurrentAdapterState();
    return state == BleAdapterState.on;
  }

  @override
  Future<BlePermissionStatus> checkPermission() =>
      _permissionService.checkPermission();

  @override
  Future<BlePermissionStatus> requestPermission() =>
      _permissionService.requestPermission();

  @override
  Future<bool> openAppSettings() => _permissionService.openAppSettings();

  @override
  Future<void> startForegroundScan({Duration? timeout}) {
    if (_disposed) {
      return Future<void>.error(
        const BleException('BLE scanning repository has been disposed.'),
      );
    }
    if (_activeStartFuture != null) {
      return _activeStartFuture!;
    }
    if (_dataSource.isScanningNow) {
      return Future<void>.value();
    }

    final future = _startScanInternal(timeout: timeout);
    _activeStartFuture = future;
    return future.whenComplete(() {
      if (identical(_activeStartFuture, future)) {
        _activeStartFuture = null;
      }
    });
  }

  Future<void> _startScanInternal({Duration? timeout}) async {
    try {
      final supported = await _dataSource.isSupported();
      if (!supported) {
        throw const BleException(
          'Bluetooth Low Energy is not supported on this device.',
        );
      }

      var permission = await _permissionService.checkPermission();
      if (permission == BlePermissionStatus.denied) {
        permission = await _permissionService.requestPermission();
      }

      if (permission == BlePermissionStatus.denied) {
        throw const BleException('Bluetooth scanning permission was declined.');
      }
      if (permission == BlePermissionStatus.permanentlyDenied) {
        throw const BleException(
          'Bluetooth scanning permission is permanently denied. Enable it in app settings.',
        );
      }
      if (permission == BlePermissionStatus.unsupported) {
        throw const BleException(
          'Bluetooth permissions are unavailable on this platform.',
        );
      }

      final adapterState = await _dataSource.getCurrentAdapterState();
      if (adapterState != BleAdapterState.on) {
        throw const BleException(
          'Bluetooth is turned off. Enable Bluetooth to scan for nearby beacons.',
        );
      }

      if (_dataSource.isScanningNow) {
        return;
      }

      await _dataSource.startScan(
        withServices: const [PoiBeaconProtocolConstants.serviceUuid],
        timeout: timeout,
      );
    } on BleException {
      rethrow;
    } on FlutterBluePlusException catch (error, stackTrace) {
      _logger?.error(
        'BleScan',
        'BLE scan failed to start',
        error: error,
        stackTrace: stackTrace,
      );
      throw BleException(
        error.description ?? 'Unable to start Bluetooth scanning.',
        cause: error,
      );
    } on PlatformException catch (error, stackTrace) {
      _logger?.error(
        'BleScan',
        'Platform error while starting BLE scan',
        error: error,
        stackTrace: stackTrace,
      );
      throw BleException(
        error.message ?? 'Unable to start Bluetooth scanning.',
        cause: error,
      );
    } catch (error, stackTrace) {
      _logger?.error(
        'BleScan',
        'Unexpected error while starting BLE scan',
        error: error,
        stackTrace: stackTrace,
      );
      throw BleException('Unable to start Bluetooth scanning.', cause: error);
    }
  }

  @override
  Future<void> stopScan() async {
    if (_disposed) return;
    try {
      if (_dataSource.isScanningNow) {
        await _dataSource.stopScan();
      }
    } catch (error, stackTrace) {
      _logger?.warning(
        'BleScan',
        'Error while stopping BLE scan',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      if (_dataSource.isScanningNow) {
        await _dataSource.stopScan();
      }
    } catch (_) {
      // Best-effort cleanup during repository disposal.
    }
  }
}
