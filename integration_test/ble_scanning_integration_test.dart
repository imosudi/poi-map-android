import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android BLE scanning repository and controller initialise and dispose cleanly',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(bleScanningRepositoryProvider);
      final supported = await repository.isSupported();
      expect(supported, isA<bool>());

      final initialState = container.read(bleScanControllerProvider);
      expect(initialState.status, BleScanSessionStatus.idle);

      final permissionStatus = await repository.checkPermission();
      expect(permissionStatus, isA<BlePermissionStatus>());

      // Stopping when idle should be a safe no-op.
      await container.read(bleScanControllerProvider.notifier).stopScanning();
      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.idle,
      );
    },
  );
}

