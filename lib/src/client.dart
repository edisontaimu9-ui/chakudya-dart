import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'generated.dart';

/// Default API address.
const String defaultBaseUrl = 'https://api.chakudya.xyz';

/// Thrown for any non-2xx reply, an `{"status": "error"}` body, a timeout or a
/// network failure ([statusCode] is 0 for the last two).
class ChakudyaApiException implements Exception {
  ChakudyaApiException(this.message, this.statusCode, [this.body]);

  final String message;
  final int statusCode;

  /// Decoded JSON body, or the raw text when the reply was not JSON.
  final Object? body;

  @override
  String toString() => 'ChakudyaApiException($statusCode): $message';
}

/// Client for the Chakudya Nutrition Registry (CNR) API.
///
/// ```dart
/// final cnr = ChakudyaClient(apiKey: const String.fromEnvironment('CHAKUDYA_KEY'));
/// final maize = await cnr.foods.search(query: {'q': 'maize'});
/// ```
///
/// Every route except `GET /` and `GET /health` needs an API key.
class ChakudyaClient with ChakudyaNamespaces {
  ChakudyaClient({
    String baseUrl = defaultBaseUrl,
    this.apiKey,
    this.loginToken,
    this.timeout = const Duration(seconds: 20),
    http.Client? httpClient,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  final String baseUrl;

  /// Consumer, reviewer or admin key (sent as a Bearer token).
  final String? apiKey;

  /// Access token from a developer login. Only `/developer/...` routes use it.
  final String? loginToken;

  final Duration timeout;

  final http.Client _http;
  final bool _ownsHttp;

  /// `GET /` (API index, no key needed).
  Future<dynamic> root() => get('/');

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      request('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      request('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body, Map<String, dynamic>? query}) =>
      request('PUT', path, body: body, query: query);

  Future<dynamic> patch(String path, {Object? body, Map<String, dynamic>? query}) =>
      request('PATCH', path, body: body, query: query);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      request('DELETE', path, query: query);

  /// Sends one request and returns the decoded `data` field (or the whole JSON
  /// body when there is no `data`, or the raw text for CSV/text exports).
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/json';
    final token = path.startsWith('/developer') && loginToken != null ? loginToken : apiKey;
    if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw ChakudyaApiException('Request timed out after ${timeout.inSeconds}s', 0);
    } on http.ClientException catch (e) {
      throw ChakudyaApiException('Network error: ${e.message}', 0);
    }

    final raw = res.body;
    final ctype = res.headers['content-type'] ?? '';
    Object? decoded;
    if (ctype.contains('json') || RegExp(r'^\s*[\[{]').hasMatch(raw)) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        decoded = null;
      }
    }

    final map = decoded is Map ? decoded : null;
    final isOk = res.statusCode >= 200 && res.statusCode < 300;
    if (!isOk || map?['status'] == 'error') {
      final msg = map?['message'] ?? map?['error'] ?? 'Request failed (${res.statusCode})';
      throw ChakudyaApiException('$msg', res.statusCode, decoded ?? raw);
    }
    if (decoded == null) return raw;
    if (map != null && map.containsKey('data')) return map['data'];
    return decoded;
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final params = <String, String>{};
    query?.forEach((k, v) {
      if (v == null || v == '') return;
      params[k] = v is Iterable ? v.join(',') : '$v';
    });
    final uri = Uri.parse('$baseUrl$path');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  /// Closes the internal HTTP client (no-op if you passed your own).
  void close() {
    if (_ownsHttp) _http.close();
  }
}
