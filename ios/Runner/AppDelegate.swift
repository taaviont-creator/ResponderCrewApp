import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var wakelockChannel: FlutterMethodChannel?
  private var notificationChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    notificationChannel = FlutterMethodChannel(name: "respondcrew/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    notificationChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "getSettings":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            result([
              "notificationsEnabled": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
              "channelSound": settings.soundSetting == .enabled
            ])
          }
        }
      case "openAppNotifications":
        let address: String
        if #available(iOS 15.4, *) { address = UIApplication.openNotificationSettingsURLString }
        else { address = UIApplication.openSettingsURLString }
        guard let url = URL(string: address) else {
          result(FlutterError(code: "unavailable", message: "Seade pole saadaval", details: nil)); return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          if opened { result(nil) }
          else { result(FlutterError(code: "unavailable", message: "Seadet ei saanud avada", details: nil)) }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
    wakelockChannel = FlutterMethodChannel(
      name: "respondcrew/wakelock",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    wakelockChannel?.setMethodCallHandler { call, result in
      guard call.method == "toggle" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enable"] as? Bool else {
        result(FlutterError(code: "invalid-argument", message: "enable must be a boolean", details: nil))
        return
      }
      UIApplication.shared.isIdleTimerDisabled = enabled
      result(nil)
    }
  }
}

// Kept in the existing source file so no additional Xcode source registration is needed.
@objc class SceneDelegate: FlutterSceneDelegate {}
