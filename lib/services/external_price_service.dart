// lib/services/external_price_service.dart
//
// Concrete PriceDataSource backed by an external REST API.
// Drop-in replacement for the Firestore source — PriceProvider is unaware
// of which implementation is active.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/models/product_model.dart';
import 'price_data_source.dart';

/// Configuration bag — load from env vars or a secrets file; never hard-code.
class ExternalApiConfig {
  const ExternalApiConfig({
    required this.baseUrl,
    required this.apiKey,
    this.pollIntervalSeconds = 300,
    this.timeoutSeconds = 15,
  });

  final String baseUrl;
  final String apiKey;

  /// How often watchAllProducts() re-fetches. Default: every 5 minutes.
  final int pollIntervalSeconds;

  /// Per-request timeout.
  final int timeoutSeconds;
}

class ExternalPriceService implements PriceDataSource {
  ExternalPriceService(this._config) : _client = http.Client();

  final ExternalApiConfig _config;
  final http.Client _client;

  // Internal broadcast stream used by watchAllProducts().
  final StreamController<List<ProductModel>> _streamController =
      StreamController<List<ProductModel>>.broadcast();

  Timer? _pollTimer;
  bool _disposed = false;

  // ─── PriceDataSource ────────────────────────────────────────────────────────

  @override
  Future<List<ProductModel>> fetchAllProducts() async {
    final uri = Uri.parse('${_config.baseUrl}/products');
    final response = await _get(uri);
    final List<dynamic> body = json.decode(response.body) as List<dynamic>;
    return body
        .map((e) => ProductModel.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProductModel> fetchProduct(String productId) async {
    final uri = Uri.parse('${_config.baseUrl}/products/$productId');
    final response = await _get(uri);
    final Map<String, dynamic> body =
        json.decode(response.body) as Map<String, dynamic>;
    return ProductModel.fromApiJson(body);
  }

  @override
  Stream<List<ProductModel>> watchAllProducts() {
    _startPolling();
    return _streamController.stream;
  }

  @override
  Future<List<PricePoint>> fetchPriceHistory(
    String productId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final uri = Uri.parse(
      '${_config.baseUrl}/products/$productId/history',
    ).replace(queryParameters: params.isNotEmpty ? params : null);

    final response = await _get(uri);
    final List<dynamic> body = json.decode(response.body) as List<dynamic>;
    return body
        .map((e) => PricePoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _pollTimer?.cancel();
    await _streamController.close();
    _client.close();
  }

  // ─── Internals ───────────────────────────────────────────────────────────────

  /// Builds auth headers. Adapt the scheme (Bearer, x-api-key, etc.) to match
  /// whatever the external provider requires.
  Map<String, String> get _headers => {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
    'x-api-key': _config.apiKey,
  };

  /// Executes a GET request and throws a descriptive [ApiException] on failure.
  Future<http.Response> _get(Uri uri) async {
    late http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: _config.timeoutSeconds));
    } on TimeoutException {
      throw ApiException('Request timed out: $uri');
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    throw ApiException(
      'HTTP ${response.statusCode} from $uri — ${response.body}',
      statusCode: response.statusCode,
    );
  }

  void _startPolling() {
    if (_pollTimer != null) return; // already running
    // Emit immediately so the UI gets data without waiting for the first tick.
    _poll();
    _pollTimer = Timer.periodic(
      Duration(seconds: _config.pollIntervalSeconds),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (_disposed) return;
    try {
      final products = await fetchAllProducts();
      if (!_disposed) _streamController.add(products);
    } catch (e) {
      if (!_disposed) _streamController.addError(e);
    }
  }
}

/// Typed exception for API-layer errors.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException: $message';
}
