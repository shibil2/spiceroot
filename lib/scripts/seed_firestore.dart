// One-time Firestore seed for Kerala Rate.
//
// Pushes all 10 Kerala products (30-day mock history) and admin/config.
//
// Run once:
//   flutter run -t lib/scripts/seed_firestore.dart
//
// With strict security rules, sign in as admin first:
//   flutter run -t lib/scripts/seed_firestore.dart \
//     --dart-define=ADMIN_EMAIL=admin@keralarate.app \
//     --dart-define=ADMIN_PASSWORD=your-password
//
// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/price_data.dart';
import '../firebase_options.dart';
import '../services/firestore_service.dart';

const _adminEmail = String.fromEnvironment('ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('ADMIN_PASSWORD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SeedFirestoreApp());
}

class SeedFirestoreApp extends StatefulWidget {
  const SeedFirestoreApp({super.key});

  @override
  State<SeedFirestoreApp> createState() => _SeedFirestoreAppState();
}

class _SeedFirestoreAppState extends State<SeedFirestoreApp> {
  String _status = 'Preparing…';
  bool _done = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _runSeed();
  }

  Future<void> _runSeed() async {
    try {
      if (_adminEmail.isNotEmpty && _adminPassword.isNotEmpty) {
        setState(() => _status = 'Signing in as admin…');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
      }

      setState(
        () => _status =
            'Seeding ${keralaProducts.length} products into Firestore…',
      );

      await FirestoreService().seedDatabase();

      setState(() {
        _status =
            'Done — ${keralaProducts.length} products and admin/config written.';
        _done = true;
      });
      print(_status);
      for (final p in keralaProducts) {
        print('  ${p.id}: ${p.nameEn} ₹${p.currentPrice}');
      }
    } catch (e, st) {
      setState(() {
        _status = 'Seed failed: $e';
        _error = true;
      });
      print('Seed failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Seed Firestore')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_done && !_error)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(),
                  ),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _error ? Colors.red : null,
                  ),
                ),
                if (_error) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tip: pass ADMIN_EMAIL and ADMIN_PASSWORD via --dart-define, '
                    'or temporarily use permissive rules for the first seed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
