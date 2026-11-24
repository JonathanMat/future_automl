import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Opens this app's page in Settings, so a player who refused the
    // camera can still allow it (see CameraPermissionService).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpellDuelAppSettings")
    else { return }
    let channel = FlutterMethodChannel(
      name: "spell_duel/app_settings", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }
    }
  }
}
