import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Day 22 — register the BGProcessingTask handler before
    // `application:didFinishLaunchingWithOptions` returns, as Apple requires.
    let controller = window?.rootViewController as? FlutterViewController
    BackgroundProcessingHandler.register(with: controller?.binaryMessenger)

    // Schedule the first BGProcessing run so the engine starts watching even
    // before the user explicitly opts in (low-cost; iOS only fires it when
    // it deems appropriate).
    BackgroundProcessingHandler.scheduleNext()

    // Day 28 — register the iOS audio-capture engine (mirrors Android's
    // AudioCaptureService). Method + event channels are wired here; the
    // engine itself only starts when Flutter calls `start`.
    if let messenger = controller?.binaryMessenger {
        AudioCaptureEngine.register(with: messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
