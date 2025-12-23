import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logarte/logarte.dart';

import 'package:flutter_frontend/src/core/config/api_config.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/core/network/auth_refresh_interceptor.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';

class TransactionService {
  final _storageService = StorageService();
  final Dio _dio;
  final Logarte _logarte = logarte;

  TransactionService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
              ),
            ) {
    _dio.interceptors.add(AuthRefreshInterceptor(dio: _dio));
    _dio.interceptors.add(LogarteDioInterceptor(_logarte));
  }

  Future<Map<String, dynamic>> createTransaction({
    required double amount,
    required String type,
    required String name,
    required String description,
    String? categoryId,
    DateTime? date,
  }) async {
    try {
      final headers = await _storageService.buildAuthHeaders(
        extra: {
          'Content-Type': 'application/json',
        },
      );

      final payload = <String, dynamic>{
        'amount': amount,
        'type': type,
        'name': name,
        'description': description,
        'date': (date ?? DateTime.now()).toIso8601String(),
      };

      if (categoryId != null && categoryId.isNotEmpty) {
        payload['category_id'] = categoryId;
      }

      final response = await _dio.post(
        ApiConfig.transactionsEndpoint,
        data: payload,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == HttpStatus.ok || response.statusCode == HttpStatus.created) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        _logarte.log('createTransaction success: $data');
        return {
          'success': true,
          'data': data,
          'message': 'Transaction created successfully',
        };
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        _logarte.log('createTransaction non-200: $data');
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? data['detail'] ?? 'Failed to create transaction',
        };
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('createTransaction error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is Map && data['message'] != null) return data['message'].toString();
        if (data is Map && data['error'] != null) return data['error'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _logarte.log('createTransaction error (non-dio): $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> sumTransaction({
    required String start_date,
    required String end_date,
    String type = 'expense',
    String? categoryId,
  }) async {
    try {
      final headers = await _storageService.buildAuthHeaders(
        extra: {
          'Content-Type': 'application/json',
        },
      );

      final payload = <String, dynamic>{
        'start_date': start_date,
        'end_date': end_date,
        'type': type,
      };

      if (categoryId != null && categoryId.isNotEmpty) {
        payload['category_id'] = categoryId;
      }

      final response = await _dio.get(
        ApiConfig.sumTransactionsEndpoint,
        queryParameters: payload,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': true,
          'data': data,
        };
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? data['detail'] ?? 'Failed to sum transaction',
        };
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('sumTransaction error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is Map && data['message'] != null) return data['message'].toString();
        if (data is Map && data['error'] != null) return data['error'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _logarte.log('sumTransaction error (non-dio): $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> newTransaction({
    String? start_date,
    String? end_date,
    String? type,
    String? categoryId,
    String? cursor,
    int? limit,
  }) async {
    try {
      final headers = await _storageService.buildAuthHeaders(
        extra: {
          'Content-Type': 'application/json',
        },
      );

      final payload = <String, dynamic>{};

      if (limit != null) {
        payload['limit'] = limit;
      }

      if (type != null && type.isNotEmpty) {
        payload['type'] = type;
      }

      if (start_date != null && start_date.isNotEmpty) {
        payload['start_date'] = start_date;
      }

      if (end_date != null && end_date.isNotEmpty) {
        payload['end_date'] = end_date;
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        payload['category_id'] = categoryId;
      }

      if (cursor != null && cursor.isNotEmpty) {
        payload['cursor'] = cursor;
      }

      final response = await _dio.get(
        ApiConfig.transactionsEndpoint,
        queryParameters: payload,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': true,
          'data': data,
        };
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? data['detail'] ?? 'Failed to new transaction',
        };
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('newTransaction error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is Map && data['message'] != null) return data['message'].toString();
        if (data is Map && data['error'] != null) return data['error'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _logarte.log('newTransaction error (non-dio): $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> fetchTransactions({
    String? cursor,
    int limit = 20,
    String? startDate,
    String? endDate,
    String? type,
    String? categoryId,
  }) async {
    try {
      final headers = await _storageService.buildAuthHeaders(
        extra: {
          'Content-Type': 'application/json',
        },
      );

      final payload = <String, dynamic>{
        'limit': limit,
      };

      if (cursor != null && cursor.isNotEmpty) {
        payload['cursor'] = cursor;
      }
      if (startDate != null && startDate.isNotEmpty) {
        payload['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        payload['end_date'] = endDate;
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        payload['type'] = type;
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        payload['category_id'] = categoryId;
      }

      final response = await _dio.get(
        ApiConfig.transactionsEndpoint,
        queryParameters: payload,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': true,
          'data': data,
        };
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? data['detail'] ?? 'Failed to load transactions',
        };
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('fetchTransactions error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is Map && data['message'] != null) return data['message'].toString();
        if (data is Map && data['error'] != null) return data['error'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _logarte.log('fetchTransactions error (non-dio): $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> transactionsTimeFrame({
    String type = 'today',
  }) async {
    try {
      final headers = await _storageService.buildAuthHeaders(
        extra: {
          'Content-Type': 'application/json',
        },
      );

      final payload = <String, dynamic>{
        'type': type,
      };

      final response = await _dio.get(
        "${ApiConfig.transactionsTimeFrameEndpoint}$type",
        queryParameters: payload,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': true,
          'data': data,
        };
      } else {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? data['detail'] ?? 'Failed to new transaction',
        };
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      _logarte.log('newTransaction error: ${e.message} data=$data');
      final message = () {
        if (data is Map && data['detail'] != null) return data['detail'].toString();
        if (data is Map && data['message'] != null) return data['message'].toString();
        if (data is Map && data['error'] != null) return data['error'].toString();
        if (data is String && data.isNotEmpty) return data;
        return 'Connection error: ${e.message}';
      }();
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _logarte.log('newTransaction error (non-dio): $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}
