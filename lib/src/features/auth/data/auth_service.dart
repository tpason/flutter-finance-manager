import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logarte/logarte.dart';

import 'package:flutter_frontend/src/core/config/api_config.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';

class AuthService {
  final _storageService = StorageService();
  final Dio _dio;
  final Logarte _logarte = logarte;

  AuthService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
              ),
            ) {
    _dio.interceptors.add(LogarteDioInterceptor(_logarte));
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final clientSecret = dotenv.env['CLIENT_SECRET'];
      final clientId = dotenv.env['CLIENT_ID'] ?? 'string';

      final payload = <String, String>{
        'grant_type': 'password',
        'username': email,
        'password': password,
        'scope': '',
        'client_id': clientId,
      };

      if (clientSecret != null && clientSecret.isNotEmpty) {
        payload['client_secret'] = clientSecret;
      }

      final response = await _dio.post(
        ApiConfig.loginEndpoint,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return AuthResponse(
          success: true,
          token: data['access_token'],
          tokenType: data['token_type'] ?? 'Bearer',
          refreshToken: data['refresh_token'],
          message: 'Login successful',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['detail'] ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      return AuthResponse(
        success: false,
        message: data?['detail'] ?? 'Connection error: ${e.message}',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Connection error: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentUser([
    String? accessToken,
    String? tokenType,
  ]) async {
    try {
      final token = accessToken ?? await _storageService.getAccessToken();
      final type = _normalizeTokenType(tokenType ?? await _storageService.getTokenType());
      if (token == null) {
        _logarte.log('fetchCurrentUser skipped: missing token');
        return null;
      }

      final response = await _dio.get(
        ApiConfig.profileEndpoint,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': '$type $token',
          },
        ),
      );

      if (response.statusCode == HttpStatus.ok) {
        final user = (response.data is String
                ? jsonDecode(response.data)
                : response.data) as Map<String, dynamic>;
        logarte.log('fetchCurrentUser response: $user');
        return user;
      }
      _logarte.log('fetchCurrentUser non-200: ${response.statusCode} ${response.data}');
      return null;
    } catch (e, st) {
      _logarte.log('fetchCurrentUser error: $e', stackTrace: st);
      return null;
    }
  }


  Future<AuthResponse> register({
    required String email,
    required String username,
    required String fullName,
    required String password,
    required int limitAmount,
    String role = 'MEMBER',
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.registerEndpoint,
        data: {
          'email': email,
          'username': username,
          'full_name': fullName,
          'password': password,
          'role': role,
          'limit_amount': limitAmount,
        },
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      if (response.statusCode == HttpStatus.ok || response.statusCode == HttpStatus.created) {
        _logarte.log('register success: $data');
        return AuthResponse(
          success: true,
          user: data,
          message: 'Registration successful',
        );
      } else {
        _logarte.log('register non-200: $data');
        return AuthResponse(
          success: false,
          message: data['detail'] ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('register error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return AuthResponse(
        success: false,
        message: message,
      );
    } catch (e) {
      _logarte.log('register error (non-dio): $e');
      return AuthResponse(
        success: false,
        message: 'Connection error: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> resetPassword(String email) async {
    try {
      final response = await _dio.post(
        ApiConfig.resetPasswordEndpoint,
        data: {
          'email': email,
        },
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Password reset email sent',
        );
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return AuthResponse(
          success: false,
          message: data['message'] ?? data['error'] ?? 'Failed to send reset email',
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      return AuthResponse(
        success: false,
        message: data?['message'] ?? data?['error'] ?? 'Connection error: ${e.message}',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Connection error: ${e.toString()}',
      );
    }
  }
}

class AuthResponse {
  final bool success;
  final String? token;
  final String? tokenType;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final String message;

  AuthResponse({
    required this.success,
    this.token,
    this.tokenType,
    this.refreshToken,
    this.user,
    required this.message,
  });
}

extension AuthServiceRefresh on AuthService {
  static Completer<AuthResponse>? _refreshCompleter;
  static const _minRefreshInterval = Duration(seconds: 2);
  static DateTime? _lastRefreshAt;

  Future<AuthResponse> refreshToken() async {
    // Nếu đang refresh, chờ chung kết quả
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final now = DateTime.now();
    if (_lastRefreshAt != null && now.difference(_lastRefreshAt!) < _minRefreshInterval) {
      return AuthResponse(success: false, message: 'Refresh throttled');
    }
    _lastRefreshAt = now;

    final completer = Completer<AuthResponse>();
    _refreshCompleter = completer;

    try {
      final storedRefresh = await _storageService.getRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        final res = AuthResponse(success: false, message: 'Missing refresh token');
        completer.complete(res);
        return res;
      }

      final response = await _dio.post(
        ApiConfig.refreshEndpoint,
        data: {'refresh_token': storedRefresh},
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;

      if (response.statusCode == HttpStatus.ok) {
        final res = AuthResponse(
          success: true,
          token: data['access_token'] ?? data['token'],
          tokenType: _normalizeTokenType(data['token_type']),
          refreshToken: data['refresh_token'] ?? data['refreshToken'] ?? storedRefresh,
          message: data['message'] ?? 'Token refreshed',
        );
        await _storageService.saveAuthData(
          accessToken: res.token ?? '',
          tokenType: res.tokenType ?? 'Bearer',
          refreshToken: res.refreshToken,
        );
        completer.complete(res);
        return res;
      } else {
        final res = AuthResponse(
          success: false,
          message: data['message'] ?? data['detail'] ?? data['error'] ?? 'Unable to refresh token',
        );
        completer.complete(res); // hoặc completeError nếu bạn muốn throw
        return res;
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final res = AuthResponse(
        success: false,
        message: (data is Map ? (data['message'] ?? data['error']) : null) ??
            'Connection error: ${e.message}',
      );
      completer.complete(res);
      return res;
    } catch (e) {
      final res = AuthResponse(
        success: false,
        message: 'Connection error: ${e.toString()}',
      );
      completer.complete(res);
      return res;
    } finally {
      // chỉ clear nếu completer hiện tại chính là cái mình tạo
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  String _normalizeTokenType(String? tokenType) {
    if (tokenType == null || tokenType.isEmpty) return 'Bearer';
    final lower = tokenType.trim().toLowerCase();
    if (lower == 'bearer') return 'Bearer';
    return tokenType.trim();
  }
}
