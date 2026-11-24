package com.spellduel.spell_duel

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens this app's settings page, so a player who refused the
        // camera can still allow it (see CameraPermissionService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spell_duel/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
