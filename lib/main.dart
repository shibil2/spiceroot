import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiceroot/screens/home_screen.dart';

import 'di.dart';
import 'firebase_options.dart';
import 'providers/alerts_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/watchlist_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

/// Background FCM handler (top-level required by firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final notificationService = NotificationService();
  notificationService.setNavigatorKey(_navigatorKey);
  try {
    await notificationService.init();
  } catch (e, st) {
    debugPrint('NotificationService init failed: $e\n$st');
  }

  runApp(
    AppProviders(
      child: KeralaRateApp(notificationService: notificationService),
    ),
  );
}

class KeralaRateApp extends StatelessWidget {
  const KeralaRateApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: notificationService),
        Provider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => WatchlistProvider()..init()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()..init()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Kerala Rate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const HomeScreen(),
      ),
    );
  }
}

/// Minimal app used by widget tests.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test App')),
        body: Center(child: Text('$_counter')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _counter++),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
