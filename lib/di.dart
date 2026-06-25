// lib/di.dart
//
// Single place to wire up which PriceDataSource PriceProvider gets.
// Toggle between Firestore and the external API by flipping one constant
// (or reading it from a remote-config / build flag).

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

import 'providers/price_provider.dart';
import 'services/external_price_service.dart';
import 'services/firestore_price_service.dart';
import 'services/price_data_source.dart';

// ─── Feature flag ─────────────────────────────────────────────────────────────
//
// Flip this to true once the external API is ready; false keeps using Firestore.
const bool _useExternalApi = false;

// ─── External API config ──────────────────────────────────────────────────────
//
// Load from dart-define or a secrets package in production:
//   flutter run --dart-define=API_KEY=abc123 --dart-define=API_URL=https://...
const _apiKey = String.fromEnvironment('API_KEY', defaultValue: '');
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://api.example.com/v1',
);

PriceDataSource buildDataSource() {
  if (_useExternalApi) {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'External API enabled but API_KEY is missing; falling back to Firestore.',
        );
      }
      return FirestorePriceService();
    }

    return ExternalPriceService(
      ExternalApiConfig(
        baseUrl: _apiUrl,
        apiKey: _apiKey,
        pollIntervalSeconds: kDebugMode ? 30 : 300,
      ),
    );
  }
  return FirestorePriceService();
}

/// Wrap your MaterialApp (or relevant subtree) with this to inject PriceProvider.
///
/// ```dart
/// void main() {
///   runApp(AppProviders(child: MyApp()));
/// }
/// ```
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PriceProvider(buildDataSource()),
      child: child,
    );
  }
}
