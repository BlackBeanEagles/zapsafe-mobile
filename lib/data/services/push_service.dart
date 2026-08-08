import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/quiet_hours.dart';
import 'api_client.dart';

/// Categories the backend tags push messages with. Each drives a different
/// foreground/background behavior on the device.
enum PushCategory {
  /// Tier 1 contact acknowledged the SOS — banner only, normal priority.
  contactAck,

  /// Live SOS dispatched to this user (rare — only if I'm a contact).
  /// Wake the screen, navigate to /sos-active, full-screen takeover.
  sosAlert,

  /// Battery dropped below the LP15 critical threshold during active SOS.
  /// Normal priority, banner.
  batteryWarning,

  /// Scheduled wellness check-in reminder. Respect quiet hours.
  checkInReminder,

  /// Anything not yet categorised — falls through to default channel.
  unknown,
}

extension PushCategoryMeta on PushCategory {
  String get label => switch (this) {
        PushCategory.sosAlert         => 'SOS Alert',
        PushCategory.contactAck       => 'Contact Acknowledgement',
        PushCategory.batteryWarning   => 'Battery Warning',
        PushCategory.checkInReminder  => 'Check-in Reminder',
        PushCategory.unknown          => 'Other',
      };

  /// Route a tap on a notification of this category should navigate to.
  /// Centralised here so router + UI + tests agree on one matrix.
  String get destinationRoute => switch (this) {
        PushCategory.sosAlert        => '/sos-active',
        PushCategory.contactAck      => '/sos-active',
        PushCategory.batteryWarning  => '/sos-active',
        PushCategory.checkInReminder => '/dashboard',
        PushCategory.unknown         => '/',
      };

  /// Whether this category may be suppressed during quiet hours.
  /// SOS_ALERT is **never** suppressed — safety always wins.
  bool get suppressibleInQuietHours => switch (this) {
        PushCategory.checkInReminder => true,
        _                            => false,
      };

  String get priority => switch (this) {
        PushCategory.sosAlert         => 'CRITICAL',
        PushCategory.contactAck       => 'NORMAL',
        PushCategory.batteryWarning   => 'NORMAL',
        PushCategory.checkInReminder  => 'LOW',
        PushCategory.unknown          => 'NORMAL',
      };

  /// Server-side string used in `data.category`.
  String get wireName => switch (this) {
        PushCategory.sosAlert         => 'SOS_ALERT',
        PushCategory.contactAck       => 'CONTACT_ACK',
        PushCategory.batteryWarning   => 'BATTERY_WARNING',
        PushCategory.checkInReminder  => 'CHECK_IN_REMINDER',
        PushCategory.unknown          => 'UNKNOWN',
      };

  static PushCategory fromWire(String? wire) {
    switch (wire) {
      case 'SOS_ALERT':         return PushCategory.sosAlert;
      case 'CONTACT_ACK':       return PushCategory.contactAck;
      case 'BATTERY_WARNING':   return PushCategory.batteryWarning;
      case 'CHECK_IN_REMINDER': return PushCategory.checkInReminder;
      default:                  return PushCategory.unknown;
    }
  }
}

/// A normalised push payload — same shape whether the message arrived in
/// foreground, background, or as the cold-start launcher.
class PushPayload {
  final String? messageId;
  final PushCategory category;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const PushPayload({
    this.messageId,
    required this.category,
    this.title,
    this.body,
    this.data = const {},
  });

  factory PushPayload.fromRemote(RemoteMessage msg) {
    final cat = PushCategoryMeta.fromWire(msg.data['category'] as String?);
    return PushPayload(
      messageId: msg.messageId,
      category: cat,
      title: msg.notification?.title,
      body: msg.notification?.body,
      data: Map<String, dynamic>.from(msg.data),
    );
  }
}

/// Push permission outcome — wraps `AuthorizationStatus`.
enum PushPermissionOutcome { granted, denied, notDetermined, provisional }

/// Day 17 — kind of user action that triggered a navigation intent.
enum PushNavTrigger {
  /// User tapped the notification body itself.
  tap,

  /// User pressed the "I'm Responding" action button (SOS only).
  responding,

  /// User pressed the "Call 112" action button (SOS only).
  call112,

  /// App was launched from terminated state by the notification.
  coldStart,
}

/// Day 17 — describes "go to route X" intent the app router should honour.
@immutable
class PushNavIntent {
  final String route;
  final PushCategory category;
  final PushNavTrigger trigger;
  final Map<String, dynamic> extra;

  const PushNavIntent({
    required this.route,
    required this.category,
    required this.trigger,
    this.extra = const {},
  });

  @override
  String toString() =>
      'PushNavIntent(route: $route, category: ${category.wireName}, trigger: ${trigger.name})';
}

/// Top-level background handler. **Must be a top-level function** — FCM spawns
/// a separate isolate for background pushes and cannot reach instance methods.
/// Kept tiny on purpose; heavy work (DB writes, UI) belongs in the foreground.
@pragma('vm:entry-point')
Future<void> zapsafeFcmBackgroundHandler(RemoteMessage message) async {
  // The background isolate has its own Firebase context — re-init is required.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // No Firebase config available — let the system notification render anyway.
  }
  if (kDebugMode) {
    final cat = message.data['category'] ?? 'unknown';
    debugPrint('[push:bg] category=$cat id=${message.messageId}');
  }
}

/// Push notification service.
///
/// Designed to **gracefully degrade** when Firebase isn't configured. If
/// `google-services.json` / `GoogleService-Info.plist` are missing,
/// [Firebase.initializeApp] throws — we catch it and run in "stub mode":
///   - [getToken] returns a deterministic `STUB_FCM_TOKEN_…` string
///   - [setupHandlers] is a no-op
///   - [requestPermission] still requests the OS-level permission
///     (this works without Firebase, via permission_handler in Day 11)
///
/// This means the rest of the app can call PushService freely during local
/// dev. To wire the real thing, drop `google-services.json` into
/// `android/app/` and `GoogleService-Info.plist` into the iOS Runner target.
class PushService {
  static const _backendPath = '/api/v1/push/register/';
  static const _androidChannelId = 'zapsafe_default';
  static const _androidChannelName = 'ZapSafe Notifications';
  static const _androidSosChannelId = 'zapsafe_sos';
  static const _androidSosChannelName = 'ZapSafe SOS Alerts';

  // Day 18 — silent channel: visible but no sound/vibration.
  static const _androidSilentChannelId = 'zapsafe_silent';
  static const _androidSilentChannelName = 'ZapSafe Silent Updates';

  /// Day 18 — sentinel key inside `PushPayload.data` marking a drill push.
  /// Backend dispatch logic short-circuits when this is present.
  static const drillFlagKey = 'drill';
  static const drillTitlePrefix = '[DRILL] ';

  // ─── Action button identifiers (Day 17) ──────────────────────────────────
  // Same IDs on iOS (UNNotificationAction) and Android
  // (AndroidNotificationAction) so a single switch handles both platforms.
  static const actionResponding = 'ZAPSAFE_RESPONDING';
  static const actionCall112    = 'ZAPSAFE_CALL_112';

  // ─── iOS notification category identifier ───────────────────────────────
  // Linked to PushCategory.sosAlert — the only category with action buttons.
  static const _iosSosCategoryId = 'ZAPSAFE_SOS_ALERT';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  ApiClient? _api;

  bool _firebaseAvailable = false;
  bool get firebaseAvailable => _firebaseAvailable;

  bool _initialized = false;
  bool get initialized => _initialized;

  String? _cachedToken;
  String? get cachedToken => _cachedToken;

  void Function(PushPayload payload)? _onTap;

  /// Day 17 — quiet hours config. SOS pushes ignore this; only suppressible
  /// categories (currently CHECK_IN_REMINDER) are blocked when active.
  QuietHoursConfig _quietHours = QuietHoursConfig.defaults;
  QuietHoursConfig get quietHours => _quietHours;
  set quietHours(QuietHoursConfig cfg) => _quietHours = cfg;

  /// Day 17 — broadcast stream of navigation intents produced by notification
  /// taps and action-button presses. Consumers (a Riverpod listener wired to
  /// GoRouter) forward each intent to `router.go(intent.route)`.
  final _navController = StreamController<PushNavIntent>.broadcast();
  Stream<PushNavIntent> get navigationIntents => _navController.stream;

  /// Day 17 — exposed for testing and the cold-start path. Pushes a synthetic
  /// nav intent through the stream.
  void emitNavigationIntent(PushNavIntent intent) {
    if (!_navController.isClosed) _navController.add(intent);
  }

  /// Disposes the navigation stream. Generally called only in tests — the
  /// service lives for the app lifetime in production.
  Future<void> dispose() async {
    await _navController.close();
  }

  /// Initialises Firebase (if configured), local notifications, and channels.
  /// Safe to call multiple times — no-ops after first success.
  Future<void> init({ApiClient? api}) async {
    if (_initialized) return;
    _api = api;

    // 1. Try Firebase — falls back to stub mode if no config.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
    } catch (e) {
      _firebaseAvailable = false;
      if (kDebugMode) debugPrint('[push] Firebase init failed → stub mode: $e');
    }

    // 2. Local notifications — works without Firebase.
    await _initLocal();

    // Day 18 — timezone DB so zonedSchedule works.
    tz_data.initializeTimeZones();

    // 3. Background handler — must be set BEFORE any messages arrive.
    if (_firebaseAvailable) {
      FirebaseMessaging.onBackgroundMessage(zapsafeFcmBackgroundHandler);
    }

    _initialized = true;
  }

  Future<void> _initLocal() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Day 17 — iOS UNNotificationCategory for SOS_ALERT. Two action buttons:
    //   1. "I'm Responding" (foreground action, runs the app)
    //   2. "Call 112" (destructive style)
    // The same action IDs are reused for Android below in _showLocalNotification.
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosSosCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              actionResponding,
              "I'm Responding",
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              actionCall112,
              'Call 112',
              options: {
                DarwinNotificationActionOption.foreground,
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _local.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    // Channels (Android 8+): default + SOS (high priority, bypass DND)
    if (Platform.isAndroid) {
      final android = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Status updates, acknowledgements, reminders.',
          importance: Importance.defaultImportance,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidSosChannelId,
          _androidSosChannelName,
          description: 'Critical SOS alerts — bypass Do Not Disturb.',
          importance: Importance.max,
          enableLights: true,
          enableVibration: true,
        ),
      );

      // Day 18 — silent channel: visible but no sound, vibration, or lights.
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidSilentChannelId,
          _androidSilentChannelName,
          description: 'Background sync confirmations and silent status updates.',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
        ),
      );
    }
  }

  /// Requests notification permission (iOS prompt / Android 13+ prompt).
  /// In stub mode, this still works on Android via local_notifications.
  Future<PushPermissionOutcome> requestPermission() async {
    if (_firebaseAvailable) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized   => PushPermissionOutcome.granted,
        AuthorizationStatus.provisional  => PushPermissionOutcome.provisional,
        AuthorizationStatus.denied       => PushPermissionOutcome.denied,
        AuthorizationStatus.notDetermined => PushPermissionOutcome.notDetermined,
      };
    }

    // Stub mode: request iOS via local_notifications directly.
    if (Platform.isIOS) {
      final ios = _local.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted
          ? PushPermissionOutcome.granted
          : PushPermissionOutcome.denied;
    }
    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      return granted
          ? PushPermissionOutcome.granted
          : PushPermissionOutcome.denied;
    }
    return PushPermissionOutcome.granted;
  }

  /// Fetches the FCM token (or returns a deterministic stub in stub mode).
  /// Result is cached in [cachedToken] for UI display.
  Future<String?> getToken() async {
    if (_firebaseAvailable) {
      try {
        _cachedToken = await FirebaseMessaging.instance.getToken();
        return _cachedToken;
      } catch (e) {
        if (kDebugMode) debugPrint('[push] getToken failed: $e');
        return null;
      }
    }

    // Stub mode: emit a deterministic fake token so backend dev can still see something.
    _cachedToken =
        'STUB_FCM_TOKEN_${Platform.operatingSystem.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';
    return _cachedToken;
  }

  /// Sends the FCM token to the backend's push registration endpoint.
  /// Returns the response on success, throws [PushRegistrationException] on failure.
  ///
  /// Backend route: `PATCH /api/v1/push/register/` (built in backend Week 4).
  /// Until that route lands, this call may 404 — callers should treat that as
  /// "deferred to backend Week 4" rather than a hard error.
  Future<Map<String, dynamic>> registerWithBackend({
    required String token,
    String? deviceTier,
  }) async {
    if (_api == null) {
      throw PushRegistrationException('PushService.init was called without an ApiClient.');
    }
    try {
      final response = await _api!.dio.patch(_backendPath, data: {
        'token': token,
        'platform': Platform.operatingSystem,
        if (deviceTier != null) 'device_tier': deviceTier,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw PushRegistrationException(e.toString());
    }
  }

  /// Wires foreground + tap handlers. Pass null for either to ignore.
  ///
  /// - Foreground messages: FCM does not show a system notification when the
  ///   app is open. We display one ourselves via `flutter_local_notifications`
  ///   and invoke [onForeground] with the parsed payload.
  /// - Background taps: when the user taps a system notification while the
  ///   app is backgrounded, [onTap] fires.
  /// - Cold-start: see [getLaunchPayload].
  void setupHandlers({
    void Function(PushPayload payload)? onForeground,
    void Function(PushPayload payload)? onTap,
  }) {
    _onTap = onTap;

    if (!_firebaseAvailable) return;

    FirebaseMessaging.onMessage.listen((msg) {
      final payload = PushPayload.fromRemote(msg);
      // Route through showLocal() so quiet hours apply to FCM foreground pushes.
      showLocal(payload);
      onForeground?.call(payload);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final payload = PushPayload.fromRemote(msg);
      // Day 17 — also surface as a nav intent so the GoRouter listener
      // routes the user to the right screen automatically.
      emitNavigationIntent(PushNavIntent(
        route: payload.category.destinationRoute,
        category: payload.category,
        trigger: PushNavTrigger.tap,
      ));
      onTap?.call(payload);
    });
  }

  /// Returns the payload that launched the app from a terminated state, or
  /// null if the app was opened normally.
  Future<PushPayload?> getLaunchPayload() async {
    if (!_firebaseAvailable) return null;
    try {
      final msg = await FirebaseMessaging.instance.getInitialMessage();
      if (msg == null) return null;
      return PushPayload.fromRemote(msg);
    } catch (_) {
      return null;
    }
  }

  /// Displays a local notification — used by the foreground handler and
  /// available to the rest of the app for in-app simulation / testing.
  ///
  /// Honours [quietHours]: returns false without showing the notification if
  /// the payload's category is suppressible AND the current time is inside
  /// the quiet-hours window. SOS pushes always show.
  Future<bool> showLocal(PushPayload payload, {DateTime? now}) async {
    if (_shouldSuppress(payload, now ?? DateTime.now())) {
      if (kDebugMode) {
        debugPrint('[push] suppressed ${payload.category.wireName} — quiet hours');
      }
      return false;
    }
    await _showLocalNotification(payload);
    return true;
  }

  /// Day 17 — true when [payload] should be silently dropped due to quiet
  /// hours. SOS pushes never suppress; only categories with
  /// [PushCategoryMeta.suppressibleInQuietHours] honour the config.
  bool _shouldSuppress(PushPayload payload, DateTime now) {
    if (!payload.category.suppressibleInQuietHours) return false;
    return _quietHours.covers(now);
  }

  Future<void> _showLocalNotification(PushPayload payload) async {
    final isSos = payload.category == PushCategory.sosAlert;
    final androidDetails = AndroidNotificationDetails(
      isSos ? _androidSosChannelId : _androidChannelId,
      isSos ? _androidSosChannelName : _androidChannelName,
      importance: isSos ? Importance.max : Importance.defaultImportance,
      priority: isSos ? Priority.max : Priority.defaultPriority,
      fullScreenIntent: isSos,
      category: isSos
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.message,
      // Day 17 — Android action buttons mirror the iOS UNNotificationCategory.
      actions: isSos
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                actionResponding,
                "I'm Responding",
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                actionCall112,
                'Call 112',
                showsUserInterface: true,
              ),
            ]
          : null,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Day 17 — attach the SOS category so the action buttons render.
      categoryIdentifier: isSos ? _iosSosCategoryId : null,
    );
    await _local.show(
      payload.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payload.title ?? payload.category.label,
      payload.body ?? '',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload.category.wireName,
    );
  }

  /// Day 17 — central handler for taps + action-button presses.
  /// Resolves the right [PushNavIntent] and emits it on [navigationIntents].
  void _handleResponse(NotificationResponse resp) {
    final cat = PushCategoryMeta.fromWire(resp.payload);
    final trigger = switch (resp.actionId) {
      actionResponding => PushNavTrigger.responding,
      actionCall112    => PushNavTrigger.call112,
      _                => PushNavTrigger.tap,
    };

    // The intent's destination route depends on category, except action
    // buttons which always send the user to /sos-active.
    final route = trigger == PushNavTrigger.tap
        ? cat.destinationRoute
        : '/sos-active';

    final intent = PushNavIntent(
      route: route,
      category: cat,
      trigger: trigger,
      extra: {'actionId': resp.actionId, 'rawPayload': resp.payload},
    );

    emitNavigationIntent(intent);
    _onTap?.call(PushPayload(category: cat));
  }

  // ─── Day 18 · Scheduled + silent + drill ─────────────────────────────────

  /// Schedules a local notification to fire at [when]. Returns the
  /// notification ID — keep it if you intend to cancel later.
  ///
  /// Honours [quietHours] at fire time the same way [showLocal] does — a
  /// suppressible payload scheduled inside the quiet window will be created
  /// at the OS level (so it survives an app restart) but the actual show
  /// happens through `showLocal()`. Because the OS scheduler runs the
  /// scheduled call directly, true suppression of an already-scheduled
  /// silent push is best-effort — callers should not schedule
  /// CHECK_IN_REMINDERs inside quiet hours in the first place.
  Future<int> scheduleNotification({
    required PushPayload payload,
    required DateTime when,
  }) async {
    final id = _scheduledIdFor(payload, when);
    final scheduled = tz.TZDateTime.from(when, tz.local);
    final isSos = payload.category == PushCategory.sosAlert;

    final androidDetails = AndroidNotificationDetails(
      isSos ? _androidSosChannelId : _androidChannelId,
      isSos ? _androidSosChannelName : _androidChannelName,
      importance: isSos ? Importance.max : Importance.defaultImportance,
      priority: isSos ? Priority.max : Priority.defaultPriority,
      category: isSos
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !isSos ? true : true,
      categoryIdentifier: isSos ? _iosSosCategoryId : null,
    );

    await _local.zonedSchedule(
      id,
      payload.title ?? payload.category.label,
      payload.body ?? '',
      scheduled,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload.category.wireName,
    );

    return id;
  }

  /// Cancels a previously-scheduled notification by ID. Idempotent.
  Future<void> cancelScheduled(int id) async {
    await _local.cancel(id);
  }

  /// Cancels every pending scheduled notification.
  Future<void> cancelAllScheduled() async {
    await _local.cancelAll();
  }

  /// Returns the OS's list of currently pending notifications. Survives an
  /// app restart since the OS persists the schedule.
  Future<List<PendingNotificationRequest>> listScheduled() {
    return _local.pendingNotificationRequests();
  }

  /// Day 18 — silent notification: visible but no sound / vibration / lights.
  /// Useful for background sync confirmations or status updates that don't
  /// warrant disturbing the user.
  Future<void> showSilent({
    required String title,
    required String body,
    String? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _androidSilentChannelId,
      _androidSilentChannelName,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data,
    );
  }

  /// Day 18 — fires a drill notification: same SOS channel, same action
  /// buttons, same nav behaviour — but prefixed `[DRILL]` and carrying the
  /// [drillFlagKey] flag. The screen the user lands on inspects the flag and
  /// renders in drill mode (no backend dispatch, simulated cancel button).
  ///
  /// Returns the [PushPayload] that was rendered so callers can log it.
  Future<PushPayload> fireDrill({String? scenario}) async {
    final payload = PushPayload(
      messageId: 'drill_${DateTime.now().millisecondsSinceEpoch}',
      category: PushCategory.sosAlert,
      title: '${drillTitlePrefix}SOS Triggered',
      body:
          '$drillTitlePrefix${scenario ?? 'This is a practice run.'} No real escalation.',
      data: const {drillFlagKey: 'true'},
    );
    await showLocal(payload);
    return payload;
  }

  /// Stable notification ID for a (payload, when) pair so re-scheduling the
  /// same reminder twice doesn't accumulate duplicate pending notifications.
  int _scheduledIdFor(PushPayload payload, DateTime when) {
    final s = '${payload.category.wireName}|${when.toIso8601String()}';
    // 31-bit positive int — `pendingNotificationRequests` uses signed int IDs.
    return s.hashCode & 0x7fffffff;
  }

  /// Day 17 — call once at app start to forward a cold-start launch payload
  /// onto the [navigationIntents] stream. No-op if there was no launch
  /// payload or Firebase is in stub mode.
  Future<void> emitColdStartIntentIfAny() async {
    final payload = await getLaunchPayload();
    if (payload == null) return;
    emitNavigationIntent(PushNavIntent(
      route: payload.category.destinationRoute,
      category: payload.category,
      trigger: PushNavTrigger.coldStart,
    ));
  }
}

/// Thrown when the backend's `/push/register/` endpoint rejects the token.
class PushRegistrationException implements Exception {
  final String message;
  PushRegistrationException(this.message);
  @override
  String toString() => 'PushRegistrationException: $message';
}
