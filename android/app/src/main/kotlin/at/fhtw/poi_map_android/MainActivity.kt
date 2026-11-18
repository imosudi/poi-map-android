package at.fhtw.poi_map_android

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
