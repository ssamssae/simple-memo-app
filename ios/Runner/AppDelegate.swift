import Flutter
import UIKit

@main
class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let miniLmChannel = MiniLmChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Suppress the system shake-to-undo dialog — the app handles shake in Dart via sensors_plus.
    application.applicationSupportsShakeToEdit = false

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene lifecycle: the engine is created when the scene connects, after didFinishLaunching.
  // iOS 27 SDK builds without scene adoption trap at launch (T-261027-011).
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    if let registrar = registry.registrar(forPlugin: "memoyo-paste-button") {
      let factory = PasteButtonFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "memoyo/paste_button")
    }

    if let registrar = registry.registrar(forPlugin: "memoyo-minilm") {
      miniLmChannel.register(with: registrar.messenger())
    }
  }
}
