import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logarte/logarte.dart';

import 'package:flutter_frontend/src/core/config/api_config.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/features/auth/data/auth_service.dart';

class AuthRefreshInterceptor extends Interceptor {
  final Dio _dio;
  final AuthService _authService;
  final Logarte _logarte = logarte;

  AuthRefreshInterceptor({
    required Dio dio,
    AuthService? authService,
  })  : _dio = dio,
        _authService = authService ?? AuthService();

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status != HttpStatus.unauthorized) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    if (_shouldSkip(options)) {
      return handler.next(err);
    }

    try {
      final refresh = await _authService.refreshToken();
      if (!refresh.success || refresh.token == null) {
        return handler.next(err);
      }

      final tokenType = refresh.tokenType ?? 'Bearer';
      final token = refresh.token!;
      final updatedHeaders = Map<String, dynamic>.from(options.headers);
      updatedHeaders['Authorization'] = '$tokenType $token';

      options
        ..headers = updatedHeaders
        ..extra = {
          ...options.extra,
          'authRetry': true,
        };

      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } catch (e, st) {
      _logarte.log('AuthRefreshInterceptor retry error: $e', stackTrace: st);
      return handler.next(err);
    }
  }

  bool _shouldSkip(RequestOptions options) {
    final extra = options.extra;
    if (extra['skipAuthRefresh'] == true || extra['authRetry'] == true) {
      return true;
    }

    final uri = options.uri.toString();
    if (uri == ApiConfig.refreshEndpoint || options.path == ApiConfig.refreshEndpoint) {
      return true;
    }
    if (uri == ApiConfig.loginEndpoint ||
        uri == ApiConfig.registerEndpoint ||
        uri == ApiConfig.resetPasswordEndpoint) {
      return true;
    }

    return false;
  }
}
