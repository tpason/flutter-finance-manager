import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logarte/logarte.dart';

import 'package:flutter_frontend/src/core/config/api_config.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/core/network/auth_refresh_interceptor.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';

class CategoryService {
  final _storageService = StorageService();
  final Dio _dio;
  final Logarte _logarte = logarte;

  CategoryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
              ),
            ) {
    _dio.interceptors.add(AuthRefreshInterceptor(dio: _dio));
    _dio.interceptors.add(LogarteDioInterceptor(_logarte));
  }

  Future<List<CategoryDto>> fetchCategories({int limit = 50}) async {
    try {
      final headers = await _storageService.buildAuthHeaders();
      final response = await _dio.get(
        '${ApiConfig.categoriesEndpoint}?limit=$limit',
        options: Options(headers: headers),
      );

      if (response.statusCode == HttpStatus.ok) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final items = (data['items'] ?? []) as List<dynamic>;
        return items
            .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
            .where((c) => c.type == 'expense' || c.type == 'income')
            .toList();
      }

      _logarte.log('fetchCategories non-200: ${response.statusCode} ${response.data}');
      return [];
    } on DioException catch (e) {
      _logarte.log('fetchCategories error: ${e.message} data=${e.response?.data}');
      return [];
    } catch (e) {
      _logarte.log('fetchCategories error (non-dio): $e');
      return [];
    }
  }
}

class CategoryDto {
  final String id;
  final String name;
  final String? description;
  final String type;
  final String? color;
  final String? icon;

  CategoryDto({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.color,
    this.icon,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? '',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'color': color,
        'icon': icon,
      };
}
