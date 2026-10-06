import Flutter
import UIKit
import UserNotifications
import CoreLocation
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var wakelockChannel: FlutterMethodChannel?
  private var notificationChannel: FlutterMethodChannel?
  private var geofenceChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      GeofenceExecutionBudget.install(registry.registrar(forPlugin: "RespondCrewGeofenceBudget"))
    }
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    geofenceChannel = FlutterMethodChannel(name: "respondcrew/geofence-capabilities",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    geofenceChannel?.setMethodCallHandler { call, result in
      guard call.method == "limits" else { result(FlutterMethodNotImplemented); return }
      result(["maximumRadius": CLLocationManager().maximumRegionMonitoringDistance,
              "available": CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              "backgroundRefresh": UIApplication.shared.backgroundRefreshStatus == .available])
    }
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
        if #available(iOS 16.0, *) { address = UIApplication.openNotificationSettingsURLString }
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

// Give the headless location callback bounded time to finish its network write.
// This is a finite background task, not continuous background GPS tracking.
private final class GeofenceExecutionBudget: NSObject, FlutterPlugin {
  private var task: UIBackgroundTaskIdentifier = .invalid
  static func install(_ registrar: FlutterPluginRegistrar?) {
    if let registrar = registrar { register(with: registrar) }
  }
  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GeofenceExecutionBudget()
    let channel = FlutterMethodChannel(name: "respondcrew/geofence-budget", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "begin":
      end()
      task = UIApplication.shared.beginBackgroundTask(withName: "Readiness region update") { [weak self] in self?.end() }
      result(task != .invalid)
    case "end": end(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func end() {
    if task != .invalid { UIApplication.shared.endBackgroundTask(task); task = .invalid }
  }
}
