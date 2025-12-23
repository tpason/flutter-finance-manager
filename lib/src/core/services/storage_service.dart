import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'access_token';
  static const _tokenTypeKey = 'token_type';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_profile';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveAuthData({
    required String accessToken,
    required String tokenType,
    String? refreshToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_tokenTypeKey, _normalizeTokenType(tokenType));
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  Future<String?> getTokenType() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenTypeKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> saveUserProfile(Map<String, dynamic> user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, String>> buildAuthHeaders({
    Map<String, String>? extra,
  }) async {
    final token = await getAccessToken();
    final tokenType = _normalizeTokenType(await getTokenType());
    final headers = <String, String>{
      'Accept': 'application/json',
      if (extra != null) ...extra,
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = '$tokenType $token';
    }

    return headers;
  }

  Future<void> clearAuthData() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  String _normalizeTokenType(String? tokenType) {
    if (tokenType == null || tokenType.isEmpty) return 'Bearer';
    final lower = tokenType.trim().toLowerCase();
    if (lower == 'bearer') return 'Bearer';
    return tokenType.trim();
  }
}

