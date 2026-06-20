import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';
import '../screens/detail_screen.dart';
import '../services/firestore_service.dart';
import '../utils/format_utils.dart';

/// Android notification channel id (must match MainActivity.kt).
const String kNotificationChannelId = 'kerala_rate_prices';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseFirestore? firestore,
    FirestoreService? firestoreService,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _local = localNotifications ?? FlutterLocalNotificationsPlugin(),
       _db = firestore ?? FirebaseFirestore.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final FirebaseFirestore _db;
  final FirestoreService _firestoreService;

  static const _permissionRequestedKey = 'notification_permission_requested';

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> init() async {
    await _initLocalNotifications();
    await _requestPermissionOnFirstLaunch();
    await _registerToken();
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(initial);
      });
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final productId = response.payload;
        if (productId != null && productId.isNotEmpty) {
          _navigateToProduct(productId);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotificationChannelId,
          'Price Updates',
          description: 'Price changes and market alerts',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _requestPermissionOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_permissionRequestedKey) ?? false;

    if (!alreadyRequested) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (Platform.isIOS) {
        await _local
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      await prefs.setBool(_permissionRequestedKey, true);
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    await _db.collection('users').doc(token).set({
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title =
        message.notification?.title ??
        message.data['title'] as String? ??
        'Kerala Rate';
    final body =
        message.notification?.body ?? message.data['body'] as String? ?? '';
    final productId = message.data['productId'] as String?;

    showLocalBanner(title: title, body: body, productId: productId);
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleNavigation(message);
  }

  void _handleNavigation(RemoteMessage message) {
    final productId = message.data['productId'] as String?;
    if (productId != null && productId.isNotEmpty) {
      _navigateToProduct(productId);
    }
  }

  Future<void> _navigateToProduct(String productId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    ProductModel? product;
    try {
      product = await _firestoreService.getProduct(productId);
    } catch (e) {
      debugPrint('Failed to load product $productId: $e');
    }

    if (product == null) return;
    if (!nav.mounted) return;

    nav.push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(product: product!)),
    );
  }

  /// Foreground FCM banner and general local notifications.
  Future<void> showLocalBanner({
    required String title,
    required String body,
    String? productId,
  }) async {
    final id = productId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    await _local.show(
      id.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kNotificationChannelId,
          'Price Updates',
          channelDescription: 'Price changes and market alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: productId,
    );
  }

  /// User price-alert notification (triggered locally by PriceProvider).
  Future<void> showPriceAlert({
    required String productName,
    required double currentPrice,
    required double targetPrice,
    required String unit,
    required String productId,
  }) async {
    final title = 'Price Alert — $productName';
    final body =
        '$productName reached ${FormatUtils.price(currentPrice)}/$unit, '
        'your target was ${FormatUtils.price(targetPrice)}';

    await showLocalBanner(title: title, body: body, productId: productId);
  }
}
