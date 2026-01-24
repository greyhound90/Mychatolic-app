import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/core/bible_constants.dart';

class BibleApiClient {
  BibleApiClient({
    String? baseUrl,
    http.Client? client,
    String? Function()? tokenProvider,
    int maxRetries = 2,
  }) : _baseUrl =
           baseUrl ??
           const String.fromEnvironment('BIBLE_API_BASE_URL', defaultValue: ''),
       _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _defaultTokenProvider,
       _maxRetries = maxRetries;

  final String _baseUrl;
  final http.Client _client;
  final String? Function() _tokenProvider;
  final int _maxRetries;

  static String? _defaultTokenProvider() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Map<String, String> _headers() {
    final token = _tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    if (_baseUrl.isEmpty) {
      throw ApiException(message: 'BIBLE_API_BASE_URL belum diset.');
    }

    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.parse('$base$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _request(() => _client.get(_uri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _request(
      () =>
          _client.post(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    return _request(
      () =>
          _client.put(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<void> delete(String path) async {
    await _request(() => _client.delete(_uri(path), headers: _headers()));
  }

  Future<dynamic> _request(Future<http.Response> Function() action) async {
    Object? lastError;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await action().timeout(BibleDurations.apiTimeout);
        final status = response.statusCode;
        if (status >= 200 && status < 300) {
          if (response.body.isEmpty) return null;
          return jsonDecode(response.body);
        }

        throw ApiException(
          message: _mapStatusMessage(status),
          statusCode: status,
          details: response.body,
        );
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }

      if (attempt < _maxRetries) {
        await Future.delayed(BibleDurations.apiRetryDelay);
      }
    }

    final message = ApiErrorMapper.toUserMessage(lastError ?? 'Unknown error');
    if (lastError is ApiException) {
      throw ApiException(
        message: lastError.message,
        statusCode: lastError.statusCode,
        details: lastError.details,
      );
    }
    throw ApiException(message: message);
  }

  String _mapStatusMessage(int status) {
    if (status == 401) return 'Sesi berakhir. Silakan login ulang.';
    if (status == 403) return 'Anda tidak memiliki akses.';
    if (status == 404) return 'Data tidak ditemukan.';
    if (status >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
