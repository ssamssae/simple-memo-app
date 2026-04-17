import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "memoyo-paste-button") {
      let factory = PasteButtonFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "memoyo/paste_button")
    }

    // Suppress the system shake-to-undo dialog — the app handles shake in Dart via sensors_plus.
    application.applicationSupportsShakeToEdit = false

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
