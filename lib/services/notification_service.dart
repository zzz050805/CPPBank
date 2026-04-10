import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _permissionGranted = true;

  static const int _maxNotificationId = 2147483647;
  static const String _channelId = 'high_importance_channel_v3';
  static const String _channelName = 'Thong bao quan trong';
  static const String _channelDescription =
      'Kenh thong bao cho OTP va giao dich quan trong';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  int _nextNotificationId() {
    final int raw = DateTime.now().millisecondsSinceEpoch;
    return raw % _maxNotificationId;
  }

  Future<void> _requestPermissions({bool askIfNeeded = true}) async {
    bool granted = true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);

      final bool? enabled = await androidPlugin.areNotificationsEnabled();
      granted = enabled ?? true;

      if (!granted && askIfNeeded) {
        final bool? requested = await androidPlugin
            .requestNotificationsPermission();
        final bool? enabledAfterRequest = await androidPlugin
            .areNotificationsEnabled();
        granted = (requested ?? false) || (enabledAfterRequest ?? false);
      }
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      bool? iosGranted;
      if (askIfNeeded) {
        iosGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      granted = granted && (iosGranted ?? true);
    }

    _permissionGranted = granted;
  }

  Future<void> _recreateAndroidChannelIfNeeded() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) {
      return;
    }

    try {
      await androidPlugin.deleteNotificationChannel(_channelId);
    } catch (_) {
      // Ignore when channel does not exist yet.
    }

    await androidPlugin.createNotificationChannel(_channel);
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    await _recreateAndroidChannelIfNeeded();

    await _requestPermissions(askIfNeeded: true);

    _isInitialized = true;
  }

  Future<bool> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    if (!_permissionGranted) {
      await _requestPermissions(askIfNeeded: true);
    }

    if (!_permissionGranted) {
      debugPrint(
        'System notification skipped: permission not granted by user/device settings.',
      );
      return false;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.message,
          ticker: 'Tin nhan moi',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.notification,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails details = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosDetails,
    );

    await _plugin.show(_nextNotificationId(), title, body, details);

    debugPrint('System notification shown: $title');
    return true;
  }
}
