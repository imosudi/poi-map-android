package at.fhtw.poi_map_android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingBlePermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MAPS_CONFIG_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method == "isApiKeyConfigured") {
                result.success(hasConfiguredMapsApiKey())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLE_PERMISSIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkBlePermissions" -> result.success(evaluateBlePermissionStatus())
                "requestBlePermissions" -> requestBlePermissions(result)
                "openAppSettings" -> result.success(openApplicationSettings())
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == BLE_PERMISSION_REQUEST_CODE) {
            val pending = pendingBlePermissionResult ?: return
            pendingBlePermissionResult = null
            val allGranted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                pending.success("granted")
            } else {
                pending.success(evaluateDeniedStatus(permissions))
            }
        }
    }

    private fun requiredBlePermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun evaluateBlePermissionStatus(): String {
        val permissions = requiredBlePermissions()
        val allGranted = permissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
        }
        return if (allGranted) "granted" else "denied"
    }

    private fun requestBlePermissions(result: MethodChannel.Result) {
        if (evaluateBlePermissionStatus() == "granted") {
            result.success("granted")
            return
        }
        if (pendingBlePermissionResult != null) {
            result.error("IN_PROGRESS", "A BLE permission request is already in progress.", null)
            return
        }
        pendingBlePermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            requiredBlePermissions(),
            BLE_PERMISSION_REQUEST_CODE,
        )
    }

    private fun evaluateDeniedStatus(permissions: Array<out String>): String {
        val anyPermanentlyDenied = permissions.any { permission ->
            ContextCompat.checkSelfPermission(this, permission) !=
                PackageManager.PERMISSION_GRANTED &&
                !ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
        }
        return if (anyPermanentlyDenied) "permanentlyDenied" else "denied"
    }

    private fun openApplicationSettings(): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasConfiguredMapsApiKey(): Boolean {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }
            val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
            !apiKey.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val MAPS_CONFIG_CHANNEL = "at.fhtw.poi_map_android/maps_config"
        const val BLE_PERMISSIONS_CHANNEL = "at.fhtw.poi_map_android/ble_permissions"
        const val BLE_PERMISSION_REQUEST_CODE = 4201
    }
}
