import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Issue #16: Sends push notifications via flutter_local_notifications.
///
/// Issue #17: Apple Watch mirror — no watchOS app is needed.
/// iOS automatically mirrors any local push notification to a paired
/// Apple Watch. The notification appears on the watch with the same
/// title and body, using the watch's default notification UI.
///
/// Issue #29: Critical-risk notifications always include the crisis
/// resource line as a safety net, even if the recommendation text
/// omits it (belt-and-suspenders approach).
///
/// Issue #31: No data leaves the device here. flutter_local_notifications
/// fires OS-level local notifications — there is no server, no analytics,
/// and no network call made by this service.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once from main() before runApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        // Request permissions on first launch — required for iOS
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Fire a notification. Automatically mirrors to Apple Watch.
  ///
  /// [isCritical] appends the crisis resource line as a hard safety net.
  static Future<void> send({
    required String title,
    required String body,
    bool isCritical = false,
  }) async {
    // Issue #29: append crisis line for CRITICAL risk — belt-and-suspenders
    final safeBody = isCritical
        ? '$body\n\nNeed support now? Crisis Services Canada: 1-833-456-4566'
        : body;

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // ACTIVE interruption so it breaks through Focus modes
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    await _plugin.show(
      0, // single notification ID — only one active recommendation at a time
      title,
      safeBody,
      details,
    );
  }
}
