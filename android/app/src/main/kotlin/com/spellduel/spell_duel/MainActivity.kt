package com.spellduel.spell_duel

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Push notifications land in this channel (see the
        // default_notification_channel_id meta-data in the manifest), so
        // they pop up as heads-up and show a clear name in the settings.
        val channel = NotificationChannel(
            "challenges",
            "Uitdagingen",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Als een vriend je uitdaagt voor een duel"
            lightColor = Color.rgb(0xFF, 0xB0, 0x20)
            enableLights(true)
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

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
