import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// A non-2xx response from the backend. [code] is the `error` field of its
/// JSON body (a stable machine-readable string, e.g. `invalid_credentials`).
class ApiException implements Exception {
  const ApiException(this.status, this.code);
  final int status;
  final String code;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Thin wrapper around [http.Client] that talks to the Creative Moments
/// backend: base URL, bearer token (persisted so a relaunch stays signed in),
/// and turning non-2xx responses into [ApiException].
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;
  static const _tokenKey = 'auth_token';
  String? _token;

  /// Called whenever a request comes back 401 (session expired/invalidated).
  void Function()? onUnauthorized;

  String? get token => _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, {Object? body}) => _send('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    final req = http.Request(method, _uri(path));
    req.headers['Content-Type'] = 'application/json';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    return _decode(res);
  }

  /// Multipart upload (photos, avatars, drawing PNGs).
  Future<Map<String, dynamic>> upload(
    String method,
    String path, {
    required Uint8List bytes,
    required String filename,
    required String contentType,
    Map<String, String> fields = const {},
  }) async {
    final req = http.MultipartRequest(method, _uri(path));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.fields.addAll(fields);
    final parts = contentType.split('/');
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream'),
      ),
    );
    final res = await http.Response.fromStream(await _http.send(req));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final Map<String, dynamic> data = res.body.isEmpty ? {} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401) onUnauthorized?.call();
    throw ApiException(res.statusCode, (data['error'] as String?) ?? 'error_${res.statusCode}');
  }
}
