import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hands the Maps key to the iOS Maps SDK.
  ///
  /// The key is read from `Info.plist` rather than written here, so iOS has a
  /// single place to change it — matching how Android reads it from
  /// `gradle.properties`.
  ///
  /// This uses a runtime lookup instead of `import GoogleMaps` on purpose: the
  /// `google_maps_flutter` pod is not in the project yet, and a compile-time
  /// import of a missing module would break every iOS build. Once the plugin is
  /// added this keeps working unchanged; until then it is a no-op.
  private func configureGoogleMaps() {
    guard
      let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
      !key.isEmpty,
      let servicesClass = NSClassFromString("GMSServices") as AnyObject as? NSObjectProtocol
    else { return }

    let selector = NSSelectorFromString("provideAPIKey:")
    if servicesClass.responds(to: selector) {
      _ = servicesClass.perform(selector, with: key)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
