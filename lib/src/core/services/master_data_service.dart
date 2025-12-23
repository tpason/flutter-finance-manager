import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_frontend/src/features/plans/data/category_service.dart';

/// Simple master-data cache (categories for now, extensible later).
class MasterDataService {
  MasterDataService._();

  static final MasterDataService instance = MasterDataService._();

  final CategoryService _categoryService = CategoryService();
  List<CategoryDto>? _categories;
  DateTime? _lastCategoriesFetch;
  Future<void>? _ongoingCategories;

  List<CategoryDto> get categories => _categories ?? const [];

  /// Preload categories in background; skips network if cache is fresh (< 6h).
  Future<void> preloadCategories({bool force = false}) {
    _ongoingCategories ??= _doPreloadCategories(force: force).whenComplete(() {
      _ongoingCategories = null;
    });
    return _ongoingCategories!;
  }

  Future<void> clearCategoriesCache() async {
    _categories = null;
    _lastCategoriesFetch = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('master_categories');
    await prefs.remove('master_categories_ts');
  }

  Future<void> _doPreloadCategories({bool force = false}) async {
    try {
      await _loadCategoriesFromCache();

      if (!force &&
          _categories != null &&
          _categories!.isNotEmpty &&
          _lastCategoriesFetch != null &&
          DateTime.now().difference(_lastCategoriesFetch!) < const Duration(hours: 6)) {
        return;
      }

      final fetched = await _categoryService.fetchCategories(limit: 100);
      if (fetched.isNotEmpty) {
        _categories = fetched;
        _lastCategoriesFetch = DateTime.now();
        await _saveCategoriesToCache(fetched, _lastCategoriesFetch!);
      }
    } catch (_) {
      // Best-effort; swallow to avoid blocking app start.
    }
  }

  Future<void> _loadCategoriesFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('master_categories');
    final ts = prefs.getString('master_categories_ts');
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _categories = decoded
          .map((e) => CategoryDto.fromJson((e as Map).map((k, v) => MapEntry(k.toString(), v))))
          .toList();
      if (ts != null) {
        _lastCategoriesFetch = DateTime.tryParse(ts);
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _saveCategoriesToCache(List<CategoryDto> items, DateTime ts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString('master_categories', encoded);
    await prefs.setString('master_categories_ts', ts.toIso8601String());
  }
}

