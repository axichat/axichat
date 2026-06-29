import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private static let methodChannelName = "im.axi.axichat/apns"
  private static let eventChannelName = "im.axi.axichat/apns/events"

  private var apnsEventSink: FlutterEventSink?
  private var pendingApnsEvents: [[String: Any]] = []
  private var lastApnsRegistration: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureApnsChannels(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configureApnsChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: Self.methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "APNs bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "currentRegistration":
        result(self.lastApnsRegistration)
      case "requestRemoteNotifications":
        self.registerForRemoteNotificationsIfAuthorized(result: result)
      case "unregisterRemoteNotifications":
        self.unregisterForRemoteNotifications(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: Self.eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  private func registerForRemoteNotificationsIfAuthorized(result: FlutterResult? = nil) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      var authorized: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        authorized = true
      case .denied, .notDetermined:
        authorized = false
      @unknown default:
        authorized = false
      }
      if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral {
        authorized = true
      }

      DispatchQueue.main.async {
        guard authorized else {
          result?(FlutterError(
            code: "permission_denied",
            message: "Notification permission is not granted.",
            details: nil
          ))
          return
        }
        UIApplication.shared.registerForRemoteNotifications()
        result?(nil)
      }
    }
  }

  private func unregisterForRemoteNotifications(result: FlutterResult? = nil) {
    DispatchQueue.main.async {
      UIApplication.shared.unregisterForRemoteNotifications()
      self.lastApnsRegistration = nil
      result?(nil)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    let registration: [String: Any] = [
      "type": "registered",
      "token": token,
      "environment": apnsEnvironment(),
      "bundleId": Bundle.main.bundleIdentifier ?? "im.axi.axichat",
    ]
    lastApnsRegistration = registration
    emitApnsEvent(registration)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
    emitApnsEvent([
      "type": "registrationFailed",
      "message": error.localizedDescription,
    ])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard isRemoteNotification(notification) else {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
      return
    }
    completionHandler([])
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    apnsEventSink = events
    for event in pendingApnsEvents {
      events(event)
    }
    pendingApnsEvents.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    apnsEventSink = nil
    return nil
  }

  private func emitApnsEvent(_ event: [String: Any]) {
    DispatchQueue.main.async {
      if let sink = self.apnsEventSink {
        sink(event)
      } else {
        self.pendingApnsEvents.append(event)
      }
    }
  }

  private func isRemoteNotification(_ notification: UNNotification) -> Bool {
    return notification.request.trigger is UNPushNotificationTrigger
  }

  private func apnsEnvironment() -> String {
    if let configured = Bundle.main.object(forInfoDictionaryKey: "AxiAPNSEnvironment") as? String {
      switch configured.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "development":
        return "sandbox"
      case "production":
        return "production"
      default:
        break
      }
    }
    #if DEBUG
      return "sandbox"
    #else
      return "production"
    #endif
  }
}
