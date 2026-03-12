import Flutter
import FirebaseMessaging
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didLaunch = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Conserver l'affichage des notifications en foreground.
    UNUserNotificationCenter.current().delegate = self

    // Demander l'enregistrement APNs après l'initialisation Flutter/Firebase.
    application.registerForRemoteNotifications()

    return didLaunch
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
#if DEBUG
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
#else
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
#endif

    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("[APNS] didRegisterForRemoteNotificationsWithDeviceToken: \(token)")

    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNS] didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)")

    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
