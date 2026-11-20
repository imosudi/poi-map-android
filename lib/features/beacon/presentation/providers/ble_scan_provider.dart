import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/android_ble_permission_service.dart';
import '../../data/ble_scan_data_source.dart';
import '../../data/ble_scanning_repository_impl.dart';
import '../../domain/ble_permission_service.dart';
import '../../domain/ble_scan_models.dart';
import '../../domain/ble_scanning_repository.dart';

/// Platform permission service provider for Android BLE scanning.
final blePermissionServiceProvider = Provider<BlePermissionService>((ref) {
  return MethodChannelBlePermissionService(
    logger: ref.watch(appLoggerProvider),
  );
});

/// Data source provider wrapping platform BLE scanning APIs.
final bleScanDataSourceProvider = Provider<BleScanDataSource>((ref) {
  return const FlutterBluePlusBleDataSource();
});

/// Repository provider managing foreground BLE scanning lifecycle.
final bleScanningRepositoryProvider = Provider<BleScanningRepository>((ref) {
  final repository = BleScanningRepositoryImpl(
    dataSource: ref.watch(bleScanDataSourceProvider),
    permissionService: ref.watch(blePermissionServiceProvider),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(() {
    unawaited(repository.dispose());
  });
  return repository;
});

/// Stream provider exposing live Bluetooth adapter state updates.
final bleAdapterStateProvider = StreamProvider<BleAdapterState>((ref) {
  return ref.watch(bleScanningRepositoryProvider).adapterStateStream;
});

/// Controller managing foreground BLE scan sessions, permissions, and results.
final bleScanControllerProvider =
    NotifierProvider<BleScanController, BleScanState>(BleScanController.new);

/// Convenience provider exposing the current discovered BLE sightings as a list.
final bleScanResultsProvider = Provider<List<BleRawScanResult>>((ref) {
  final state = ref.watch(bleScanControllerProvider);
  return state.resultsByDeviceId.values.toList(growable: false);
});

final class BleScanController extends Notifier<BleScanState> {
  StreamSubscription<List<BleRawScanResult>>? _resultsSub;
  StreamSubscription<BleAdapterState>? _adapterSub;
  StreamSubscription<bool>? _scanningSub;
  Future<void>? _inFlightStart;
  bool _isDisposed = false;

  @override
  BleScanState build() {
    _isDisposed = false;
    final repository = ref.watch(bleScanningRepositoryProvider);
    _bindStreams(repository);
    ref.onDispose(() {
      _isDisposed = true;
      _cancelSubscriptions();
    });
    return const BleScanState();
  }

  void _bindStreams(BleScanningRepository repository) {
    _cancelSubscriptions();

    _resultsSub = repository.scanResultsStream.listen(
      (results) {
        if (_isDisposed) return;
        final updated = Map<String, BleRawScanResult>.from(
          state.resultsByDeviceId,
        );
        for (final result in results) {
          updated[result.deviceId] = result;
        }
        state = state.copyWith(resultsByDeviceId: Map.unmodifiable(updated));
      },
      onError: (Object error) {
        if (_isDisposed) return;
        state = state.copyWith(
          status: BleScanSessionStatus.error,
          errorMessage: 'BLE scan stream error occurred.',
        );
      },
    );

    _adapterSub = repository.adapterStateStream.listen((adapterState) {
      if (_isDisposed) return;
      if (adapterState == BleAdapterState.off && state.isScanning) {
        state = state.copyWith(
          adapterState: adapterState,
          status: BleScanSessionStatus.bluetoothOff,
          errorMessage:
              'Bluetooth was turned off. Enable Bluetooth to resume scanning.',
        );
        return;
      }
      if (adapterState == BleAdapterState.on &&
          state.status == BleScanSessionStatus.bluetoothOff) {
        state = state.copyWith(
          adapterState: adapterState,
          status: BleScanSessionStatus.idle,
          clearErrorMessage: true,
        );
        return;
      }
      state = state.copyWith(adapterState: adapterState);
    });

    _scanningSub = repository.isScanningStream.listen((isScanning) {
      if (_isDisposed) return;
      if (!isScanning && state.status == BleScanSessionStatus.scanning) {
        state = state.copyWith(status: BleScanSessionStatus.idle);
      }
    });
  }

  /// Starts a foreground BLE scan filtered for the project service UUID.
  ///
  /// Concurrent or duplicate calls while already scanning are coalesced.
  Future<void> startScanning({Duration? timeout}) {
    if (_inFlightStart != null) {
      return _inFlightStart!;
    }
    if (state.isScanning) {
      return Future<void>.value();
    }

    final future = _startScanningInternal(timeout: timeout);
    _inFlightStart = future;
    return future.whenComplete(() {
      if (identical(_inFlightStart, future)) {
        _inFlightStart = null;
      }
    });
  }

  Future<void> _startScanningInternal({Duration? timeout}) async {
    final repository = ref.read(bleScanningRepositoryProvider);
    try {
      final supported = await repository.isSupported();
      if (!supported) {
        state = state.copyWith(
          status: BleScanSessionStatus.unsupported,
          errorMessage: 'Bluetooth Low Energy is not supported on this device.',
        );
        return;
      }

      var permission = await repository.checkPermission();
      if (permission == BlePermissionStatus.denied) {
        permission = await repository.requestPermission();
      }

      if (permission == BlePermissionStatus.denied) {
        state = state.copyWith(
          status: BleScanSessionStatus.permissionDenied,
          errorMessage:
              'Bluetooth scanning permission was declined. Grant permission to discover nearby beacons.',
        );
        return;
      }

      if (permission == BlePermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          status: BleScanSessionStatus.permissionPermanentlyDenied,
          errorMessage:
              'Bluetooth scanning permission is permanently denied. Enable it in app settings.',
        );
        return;
      }

      if (permission == BlePermissionStatus.unsupported) {
        state = state.copyWith(
          status: BleScanSessionStatus.unsupported,
          errorMessage:
              'Bluetooth permissions are unavailable on this platform.',
        );
        return;
      }

      final bluetoothOn = await repository.isBluetoothEnabled();
      if (!bluetoothOn) {
        state = state.copyWith(
          adapterState: BleAdapterState.off,
          status: BleScanSessionStatus.bluetoothOff,
          errorMessage:
              'Bluetooth is turned off. Enable Bluetooth to scan for nearby beacons.',
        );
        return;
      }

      await repository.startForegroundScan(timeout: timeout);
      if (_isDisposed) return;
      state = state.copyWith(
        status: BleScanSessionStatus.scanning,
        adapterState: BleAdapterState.on,
        clearErrorMessage: true,
      );
    } on BleException catch (error) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: BleScanSessionStatus.error,
        errorMessage: error.message,
      );
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: BleScanSessionStatus.error,
        errorMessage: 'Unable to start Bluetooth scanning.',
      );
    }
  }

  /// Stops the active BLE scanning session if running.
  Future<void> stopScanning() async {
    final repository = ref.read(bleScanningRepositoryProvider);
    await repository.stopScan();
    if (_isDisposed) return;
    if (state.status == BleScanSessionStatus.scanning) {
      state = state.copyWith(status: BleScanSessionStatus.idle);
    }
  }

  /// Opens Android app settings to recover from permanently denied permissions.
  Future<bool> openAppSettings() {
    return ref.read(bleScanningRepositoryProvider).openAppSettings();
  }

  void _cancelSubscriptions() {
    unawaited(_resultsSub?.cancel());
    unawaited(_adapterSub?.cancel());
    unawaited(_scanningSub?.cancel());
    _resultsSub = null;
    _adapterSub = null;
    _scanningSub = null;
  }
}
