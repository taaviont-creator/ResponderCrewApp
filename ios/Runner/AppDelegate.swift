import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var wakelockChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
