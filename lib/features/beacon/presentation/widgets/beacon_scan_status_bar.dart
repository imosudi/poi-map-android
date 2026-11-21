import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/ble_scan_models.dart';

/// Compact, user-controlled BLE discovery bar displaying scan status,
/// permission/Bluetooth availability, and start/stop actions.
class BeaconScanStatusBar extends StatelessWidget {
  const BeaconScanStatusBar({
    super.key,
    required this.scanState,
    required this.nearbyPoiCount,
    required this.onStartScan,
    required this.onStopScan,
    required this.onOpenSettings,
    this.onToggleBluetooth,
  });

  final BleScanState scanState;
  final int nearbyPoiCount;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final VoidCallback onOpenSettings;
  final VoidCallback? onToggleBluetooth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, message, actionLabel, onAction) = _describeState();
    final isBluetoothSupported =
        scanState.status != BleScanSessionStatus.unsupported;
    final isBluetoothOn =
        scanState.adapterState == BleAdapterState.on || scanState.isScanning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: scanState.isScanning
                ? AppPalette.accent
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: scanState.isTogglingBluetooth ? null : onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(actionLabel),
            ),
          ],
          if (isBluetoothSupported && onToggleBluetooth != null) ...[
            const SizedBox(width: AppSpacing.xs),
            if (scanState.isTogglingBluetooth)
              Semantics(
                label: 'Switching Bluetooth',
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else
              Semantics(
                label: isBluetoothOn
                    ? 'Turn off Bluetooth'
                    : 'Turn on Bluetooth',
                child: SizedBox(
                  height: 32,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Switch.adaptive(
                      value: isBluetoothOn,
                      onChanged: (_) => onToggleBluetooth!(),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  (IconData, String, String?, VoidCallback?) _describeState() {
    switch (scanState.status) {
      case BleScanSessionStatus.scanning:
        final label = nearbyPoiCount == 0
            ? 'Scanning for nearby POI beacons...'
            : nearbyPoiCount == 1
            ? 'Scanning • 1 nearby sight detected'
            : 'Scanning • $nearbyPoiCount nearby sights detected';
        return (Icons.bluetooth_searching_rounded, label, 'Stop', onStopScan);
      case BleScanSessionStatus.permissionDenied:
        return (
          Icons.bluetooth_disabled_rounded,
          'Bluetooth permission is needed to detect nearby beacons.',
          'Allow',
          onStartScan,
        );
      case BleScanSessionStatus.permissionPermanentlyDenied:
        return (
          Icons.settings_bluetooth_rounded,
          'Bluetooth permission is disabled in app settings.',
          'Settings',
          onOpenSettings,
        );
      case BleScanSessionStatus.bluetoothOff:
        return (
          Icons.bluetooth_disabled_rounded,
          'Bluetooth is turned off. Enable Bluetooth to scan for beacons.',
          'Retry',
          onStartScan,
        );
      case BleScanSessionStatus.unsupported:
        return (
          Icons.bluetooth_disabled_rounded,
          'BLE beacon discovery is unavailable on this device.',
          null,
          null,
        );
      case BleScanSessionStatus.error:
        return (
          Icons.warning_amber_rounded,
          scanState.errorMessage ?? 'Unable to scan for nearby beacons.',
          'Retry',
          onStartScan,
        );
      case BleScanSessionStatus.idle:
        return (
          Icons.bluetooth_rounded,
          'Scan for nearby POI Explorer beacons',
          'Scan',
          onStartScan,
        );
    }
  }
}
