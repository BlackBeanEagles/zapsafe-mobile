//
//  BackgroundProcessingHandler.swift
//  Runner
//
//  Day 22 — iOS counterpart to Android's ZapSafeService.
//
//  iOS does not allow indefinite foreground services. Instead, we lean on
//  two OS-level primitives:
//
//   1. BGProcessingTask — registered with BGTaskScheduler at app launch.
//      Schedule re-runs every ≥15 minutes (iOS's minimum). The OS decides
//      *when* to actually run us based on battery, network, and user
//      activity heuristics — we can't force exact timing.
//
//   2. Silent remote-notification push (data-only) — when our BG task
//      hasn't run in too long, the backend sends a silent push that wakes
//      the app briefly to re-schedule itself. This is the iOS watchdog.
//
//  The DCS pipeline itself (audio + IMU + triggers) is built across
//  Days 26–30; today we wire the scheduler so Day 22's review screen can
//  confirm registration.
//

import BackgroundTasks
import Flutter
import UIKit

@objc public class BackgroundProcessingHandler: NSObject {
    /// Identifier matches Info.plist `BGTaskSchedulerPermittedIdentifiers`.
    /// Must also be reported to the Flutter side over the method channel
    /// for the Day 22 review screen.
    public static let TASK_IDENTIFIER = "com.zapsafe.dcs"

    /// 15 minutes is iOS's documented minimum gap between BGProcessing runs.
    private static let RUN_GAP_SECONDS: TimeInterval = 15 * 60

    /// Channel name mirrored on the Dart side
    /// (`lib/data/services/ios_background_handler.dart`).
    public static let CHANNEL_NAME = "com.zapsafe/ios_background"

    /// Called once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    /// Safe to call from any later point — but doing it pre-`didFinishLaunching`
    /// is required by Apple's docs.
    @objc public static func register(with messenger: FlutterBinaryMessenger?) {
        // 1. Register the BGProcessingTask runner with the scheduler.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TASK_IDENTIFIER,
            using: nil
        ) { task in
            handleDCSTask(task as! BGProcessingTask)
        }

        // 2. Wire the Flutter-side method channel.
        if let m = messenger {
            let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: m)
            channel.setMethodCallHandler { call, result in
                switch call.method {
                case "scheduleNext":
                    let ok = scheduleNext()
                    result(ok)
                case "cancel":
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TASK_IDENTIFIER)
                    result(true)
                case "taskIdentifier":
                    result(TASK_IDENTIFIER)
                case "isRegistered":
                    // No public API to query — registration only happens here,
                    // so if the channel call succeeds we have already registered.
                    result(true)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    /// Schedules the next BGProcessingTask. Returns true on success.
    @discardableResult
    public static func scheduleNext() -> Bool {
        let request = BGProcessingTaskRequest(identifier: TASK_IDENTIFIER)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: RUN_GAP_SECONDS)
        do {
            try BGTaskScheduler.shared.submit(request)
            return true
        } catch {
            NSLog("[zapsafe/ios] BG submit failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Body of the BGProcessingTask. Day 22 = stub — Days 26-30 fill in the
    /// real DCS pipeline (audio frame, IMU read, trigger inference).
    private static func handleDCSTask(_ task: BGProcessingTask) {
        // ALWAYS schedule the next run first, before doing anything that
        // might throw. iOS won't auto-reschedule for us.
        scheduleNext()

        task.expirationHandler = {
            // Called by the OS when our task window is about to elapse.
            // Mark the task as failed so iOS knows we didn't finish cleanly.
            task.setTaskCompleted(success: false)
        }

        // Day 22 stub work: log and complete.
        NSLog("[zapsafe/ios] DCS BGProcessingTask fired (stub)")
        task.setTaskCompleted(success: true)
    }
}
