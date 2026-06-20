import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Replace "YOUR_API_KEY_HERE" with your actual Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyAdi5yf30wN7wI3aF8h2GZPAD3ePjUj0vM")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
