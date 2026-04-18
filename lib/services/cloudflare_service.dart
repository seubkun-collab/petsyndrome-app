import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudflare Workers API 통신 서비스
/// 크로스 디바이스 데이터 영속성을 위한 서버 연동
class CloudflareService {
  // ⚠️ Cloudflare Workers 배포 후 실제 URL로 교체
  // 배포 전까지는 로컬 Hive만 사용하고 API 오류는 무시
  static const String _baseUrl = 'https://petsyndrome-api.REPLACE_ME.workers.dev';

  static bool _isConfigured = false;
  static String? _configuredUrl;

  /// API URL 설정 (배포 후 런타임에서 설정 가능)
  static void configure(String url) {
    _configuredUrl = url;
    _isConfigured = true;
  }

  static String get baseUrl => _configuredUrl ?? _baseUrl;

  static bool get isConfigured => _isConfigured && !baseUrl.contains('REPLACE_ME');

  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // ── 작업자 인증 ──

  /// 작업자 로그인 (서버 검증)
  static Future<Map<String, dynamic>?> workerLogin(String name, String pin) async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/worker-login'),
            headers: _headers,
            body: jsonEncode({'name': name, 'pin': pin}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] workerLogin error: $e');
      return null;
    }
  }

  /// 작업자 등록
  static Future<bool> registerWorker(String name, String pin) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/workers'),
            headers: _headers,
            body: jsonEncode({'name': name, 'pin': pin}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] registerWorker error: $e');
      return false;
    }
  }

  // ── 작업비 ──

  /// 작업비 조회
  static Future<Map<String, dynamic>?> getWorkCost() async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/workcost'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getWorkCost error: $e');
      return null;
    }
  }

  /// 작업비 저장 (변경 이력 서버에서 자동 기록)
  static Future<Map<String, dynamic>?> saveWorkCost(
      Map<String, dynamic> data, String changedBy) async {
    if (!isConfigured) return null;
    try {
      final body = {...data, 'changedBy': changedBy};
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/workcost'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] saveWorkCost error: $e');
      return null;
    }
  }

  // ── 견적 이력 ──

  /// 견적 목록 조회 (작업자 필터 옵션)
  static Future<List<Map<String, dynamic>>?> getRecipes(
      {String? workerName}) async {
    if (!isConfigured) return null;
    try {
      final queryStr =
          workerName != null && workerName.isNotEmpty ? '?worker=$workerName' : '';
      final res = await http
          .get(Uri.parse('$baseUrl/api/recipes$queryStr'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getRecipes error: $e');
      return null;
    }
  }

  /// 견적 저장
  static Future<bool> saveRecipe(Map<String, dynamic> recipe) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/recipes'),
            headers: _headers,
            body: jsonEncode(recipe),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] saveRecipe error: $e');
      return false;
    }
  }

  /// 견적 삭제
  static Future<bool> deleteRecipe(String id) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/recipes/$id'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] deleteRecipe error: $e');
      return false;
    }
  }

  // ── 원물 ──

  /// 원물 목록 조회
  static Future<List<Map<String, dynamic>>?> getIngredients() async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/ingredients'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getIngredients error: $e');
      return null;
    }
  }

  /// 원물 저장
  static Future<bool> saveIngredient(
      Map<String, dynamic> ingredient, String changedBy) async {
    if (!isConfigured) return false;
    try {
      final id = ingredient['id'] as String;
      final body = {...ingredient, 'changedBy': changedBy};
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/ingredients/$id'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] saveIngredient error: $e');
      return false;
    }
  }

  /// 원물 삭제
  static Future<bool> deleteIngredient(String id) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/ingredients/$id'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] deleteIngredient error: $e');
      return false;
    }
  }

  // ── 포장 ──

  /// 포장 목록 조회
  static Future<List<Map<String, dynamic>>?> getPackaging() async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/packaging'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getPackaging error: $e');
      return null;
    }
  }

  /// 포장 저장
  static Future<bool> savePackaging(
      Map<String, dynamic> packaging, String changedBy) async {
    if (!isConfigured) return false;
    try {
      final id = packaging['id'] as String;
      final body = {...packaging, 'changedBy': changedBy};
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/packaging/$id'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] savePackaging error: $e');
      return false;
    }
  }

  /// 초기 데이터 시드 (배포 후 1회 실행)
  static Future<bool> seedData() async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/seed'),
            headers: {
              ..._headers,
              'Authorization': 'Bearer petsyndrome_admin_seed',
            },
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] seedData error: $e');
      return false;
    }
  }

  /// 연결 테스트
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/workcost'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
