import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base_url_stub.dart' if (dart.library.io) 'api_base_url_io.dart';
import 'token_store.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const ApiException(this.statusCode, this.message, {this.code});

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return resolveDefaultBaseUrl();
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = tokenStore.accessToken;
    if (auth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final response = await _send('GET', path, auth: auth);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final response = await _send('POST', path, body: body, auth: auth);
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final response = await _send('PATCH', path, body: body, auth: auth);
    return _decode(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final response = await _send('PUT', path, body: body, auth: auth);
    return _decode(response);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final response = await _send('DELETE', path, body: body, auth: auth);
    return _decode(response);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers(auth: auth);
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
        case 'POST':
          response = await _client.post(uri, headers: headers, body: encodedBody);
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: encodedBody);
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: encodedBody);
        case 'DELETE':
          response = await _client.delete(uri, headers: headers, body: encodedBody);
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } on TimeoutException {
      throw const ApiException(0, 'Request timed out. Please try again.');
    } catch (e) {
      // Network failures (SocketException & friends). Matched by message so
      // this file also compiles for web, where dart:io is unavailable.
      if (_isNetworkError(e)) {
        throw ApiException(0, 'Cannot reach server ($baseUrl). Is the backend running?');
      }
      rethrow;
    }

    if (response.statusCode == 401 && !retried && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, body: body, auth: auth, retried: true);
      }
    }

    return response;
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = tokenStore.refreshToken;
    if (refreshToken == null) return false;

    try {
      final uri = Uri.parse('$baseUrl/api/auth/refresh');
      final response = await _client
          .post(uri, headers: _headers(auth: false), body: jsonEncode({'refreshToken': refreshToken}))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['accessToken'] as String;
        final refresh = data['refreshToken'] as String;
        await tokenStore.save(accessToken: access, refreshToken: refresh);
        return true;
      }
    } catch (_) {
      // Refresh failed, fall through
    }

    await tokenStore.clear();
    return false;
  }

  dynamic _decode(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Something went wrong (${response.statusCode})';
    String? code;
    if (body is Map<String, dynamic>) {
      if (body['error'] is String) {
        message = body['error'] as String;
      } else if (body['errors'] is List) {
        final errors = body['errors'] as List;
        if (errors.isNotEmpty && errors.first is Map<String, dynamic>) {
          message = (errors.first as Map<String, dynamic>)['msg'] as String? ?? message;
        }
      }
      code = body['code'] as String?;
    }

    throw ApiException(response.statusCode, message, code: code);
  }

  bool _isNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection aborted') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('software caused connection abort') ||
        text.contains('connection closed');
  }

  void dispose() {
    _client.close();
  }
}