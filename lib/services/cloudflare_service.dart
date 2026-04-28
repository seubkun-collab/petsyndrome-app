import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ingredient.dart';
import '../models/work_cost.dart';
import '../models/packaging.dart';
import '../models/recipe.dart';

/// Cloudflare Workers API 통신 서비스
/// KV 저장소를 백엔드로 사용 - 모든 기기에서 동일한 데이터 공유
class CloudflareService {
  static const String baseUrl = 'https://petsyndrome-api.seubkun.workers.dev';
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // ── 원물 (Ingredients) ──

  static Future<List<Ingredient>> getIngredients() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/ingredients'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        return list.map(_mapIngredient).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getIngredients error: $e');
    }
    return [];
  }

  static Future<bool> saveIngredient(Ingredient ing) async {
    try {
      final body = <String, dynamic>{
        'id': ing.id,
        'name': ing.name,
        'type': ing.type,
        'unitPrice': ing.unitPrice,
        'moisture': ing.moisture,
        'crudeProtein': ing.crudeProtein,
        'crudeFat': ing.crudeFat,
        'crudeAsh': ing.crudeAsh,
        'crudeFiber': ing.crudeFiber,
        'calcium': ing.calcium,
        'phosphorus': ing.phosphorus,
        'isActive': ing.isActive,
        'bulkWeightKg': ing.bulkWeightKg,
        'history': <Map<String, dynamic>>[],
      };
      final bodyJson = jsonEncode(body);
      debugPrint('[CF] PUT /api/ingredients/${ing.id} ${ing.name} price=${ing.unitPrice}');
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/ingredients/${ing.id}'),
            headers: _headers,
            body: bodyJson,
          )
          .timeout(_timeout);
      debugPrint('[CF] PUT /api/ingredients/${ing.id} → ${res.statusCode}');
      if (res.statusCode == 404) {
        final postRes = await http
            .post(
              Uri.parse('$baseUrl/api/ingredients'),
              headers: _headers,
              body: bodyJson,
            )
            .timeout(_timeout);
        debugPrint('[CF] POST /api/ingredients → ${postRes.statusCode}');
        return postRes.statusCode == 201;
      }
      return res.statusCode == 200;
    } catch (e, st) {
      debugPrint('[CF] saveIngredient error: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteIngredient(String id) async {
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

  // ── 작업비 (WorkCost) ──

  static Future<WorkCost?> getWorkCost() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/workcost'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return _mapWorkCost(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getWorkCost error: $e');
    }
    return null;
  }

  static Future<bool> saveWorkCost(WorkCost wc, {String changedBy = '관리자'}) async {
    try {
      final body = <String, dynamic>{
        'id': wc.id,
        'dryingCost': wc.dryingCost,
        'mixingCost': wc.mixingCost,
        'cuttingCost': wc.cuttingCost,
        'cuttingLossRate': wc.cuttingLossRate,
        'marginRate': wc.marginRate,
        'changedBy': changedBy,
        'history': <Map<String, dynamic>>[],
      };
      final bodyJson = jsonEncode(body);
      debugPrint('[CF] PUT /api/workcost body=$bodyJson');
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/workcost'),
            headers: _headers,
            body: bodyJson,
          )
          .timeout(_timeout);
      debugPrint('[CF] PUT /api/workcost → ${res.statusCode} ${res.body.substring(0, res.body.length.clamp(0, 100))}');
      return res.statusCode == 200;
    } catch (e, st) {
      debugPrint('[CF] saveWorkCost error: $e\n$st');
      return false;
    }
  }

  // ── 포장 (Packagings) ──

  static Future<List<Packaging>> getPackagings() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/packagings'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        return list.map(_mapPackaging).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getPackagings error: $e');
    }
    return [];
  }

  static Future<bool> savePackaging(Packaging pkg) async {
    try {
      final body = <String, dynamic>{
        'id': pkg.id,
        'name': pkg.name,
        'category': pkg.category,
        'containerPrice': pkg.containerPrice,
        'packagingCost': pkg.packagingCost,
        'volumeCC': pkg.volumeCC,
        'isActive': pkg.isActive,
        'sortOrder': pkg.sortOrder,
        'history': <Map<String, dynamic>>[],
      };
      final bodyJson = jsonEncode(body);
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/packagings/${pkg.id}'),
            headers: _headers,
            body: bodyJson,
          )
          .timeout(_timeout);
      debugPrint('[CF] PUT /api/packagings/${pkg.id} → ${res.statusCode}');
      if (res.statusCode == 404) {
        final postRes = await http
            .post(
              Uri.parse('$baseUrl/api/packagings'),
              headers: _headers,
              body: bodyJson,
            )
            .timeout(_timeout);
        return postRes.statusCode == 201;
      }
      return res.statusCode == 200;
    } catch (e, st) {
      debugPrint('[CF] savePackaging error: $e\n$st');
      return false;
    }
  }

  static Future<bool> deletePackaging(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/packagings/$id'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] deletePackaging error: $e');
      return false;
    }
  }

  // ── 레시피 (Recipes) ──

  static Future<List<Recipe>> getRecipes({String? workerName}) async {
    try {
      final queryStr = workerName != null && workerName.isNotEmpty
          ? '?worker=$workerName'
          : '';
      final res = await http
          .get(Uri.parse('$baseUrl/api/recipes$queryStr'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        return list.map(_mapRecipe).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] getRecipes error: $e');
    }
    return [];
  }

  static Future<bool> saveRecipe(Recipe recipe) async {
    try {
      final body = _recipeToMap(recipe);
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/recipes'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('[CF] saveRecipe error: $e');
      return false;
    }
  }

  static Future<bool> deleteRecipe(String id) async {
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

  // ── 연결 테스트 ──
  static Future<bool> testConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── JSON ↔ 모델 변환 ──

  static Ingredient _mapIngredient(Map<String, dynamic> m) {
    return Ingredient(
      id: m['id'] as String,
      name: m['name'] as String,
      type: m['type'] as String,
      unitPrice: (m['unitPrice'] as num).toDouble(),
      moisture: (m['moisture'] as num).toDouble(),
      crudeProtein: (m['crudeProtein'] as num?)?.toDouble(),
      crudeFat: (m['crudeFat'] as num?)?.toDouble(),
      crudeAsh: (m['crudeAsh'] as num?)?.toDouble(),
      crudeFiber: (m['crudeFiber'] as num?)?.toDouble(),
      calcium: (m['calcium'] as num?)?.toDouble(),
      phosphorus: (m['phosphorus'] as num?)?.toDouble(),
      isActive: m['isActive'] as bool? ?? true,
      bulkWeightKg: (m['bulkWeightKg'] as num?)?.toDouble() ?? 10.0,
      ref300ccWeightG: (m['ref300ccWeightG'] as num?)?.toDouble() ?? 0.0,
      updatedAt: m['updatedAt'] != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      history: (m['history'] as List?)?.map((h) => IngredientHistory(
        changedAt: DateTime.tryParse(h['changedAt'] as String? ?? '') ?? DateTime.now(),
        unitPrice: (h['unitPrice'] as num).toDouble(),
        moisture: (h['moisture'] as num).toDouble(),
        note: h['note'] as String? ?? '',
      )).toList() ?? [],
    );
  }

  static Map<String, dynamic> _ingredientToMap(Ingredient ing) => {
    'id': ing.id,
    'name': ing.name,
    'type': ing.type,
    'unitPrice': ing.unitPrice,
    'moisture': ing.moisture,
    'crudeProtein': ing.crudeProtein,
    'crudeFat': ing.crudeFat,
    'crudeAsh': ing.crudeAsh,
    'crudeFiber': ing.crudeFiber,
    'calcium': ing.calcium,
    'phosphorus': ing.phosphorus,
    'isActive': ing.isActive,
    'bulkWeightKg': ing.bulkWeightKg,
    'ref300ccWeightG': ing.ref300ccWeightG,
    'updatedAt': ing.updatedAt.toIso8601String(),
    'history': <Map<String, dynamic>>[],  // 히스토리는 서버에서 자동 관리
  };

  static WorkCost _mapWorkCost(Map<String, dynamic> m) {
    return WorkCost(
      id: m['id'] as String? ?? 'default',
      dryingCost: (m['dryingCost'] as num).toDouble(),
      mixingCost: (m['mixingCost'] as num).toDouble(),
      cuttingCost: (m['cuttingCost'] as num).toDouble(),
      cuttingLossRate: (m['cuttingLossRate'] as num).toDouble(),
      marginRate: (m['marginRate'] as num).toDouble(),
      changedBy: m['changedBy'] as String? ?? '관리자',
      updatedAt: m['updatedAt'] != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      history: (m['history'] as List?)?.map((h) => WorkCostHistory(
        changedAt: DateTime.tryParse(h['changedAt'] as String? ?? '') ?? DateTime.now(),
        dryingCost: (h['dryingCost'] as num).toDouble(),
        mixingCost: (h['mixingCost'] as num).toDouble(),
        cuttingCost: (h['cuttingCost'] as num).toDouble(),
        cuttingLossRate: (h['cuttingLossRate'] as num).toDouble(),
        marginRate: (h['marginRate'] as num).toDouble(),
        note: h['note'] as String? ?? '',
        changedBy: h['changedBy'] as String? ?? '관리자',
      )).toList() ?? [],
    );
  }

  static Map<String, dynamic> _workCostToMap(WorkCost wc) => {
    'id': wc.id,
    'dryingCost': wc.dryingCost,
    'mixingCost': wc.mixingCost,
    'cuttingCost': wc.cuttingCost,
    'cuttingLossRate': wc.cuttingLossRate,
    'marginRate': wc.marginRate,
    'changedBy': wc.changedBy,
    'updatedAt': wc.updatedAt.toIso8601String(),
    'history': <Map<String, dynamic>>[],  // 히스토리는 서버에서 자동 관리
  };

  static Packaging _mapPackaging(Map<String, dynamic> m) {
    return Packaging(
      id: m['id'] as String,
      name: m['name'] as String,
      category: m['category'] as String,
      containerPrice: (m['containerPrice'] as num).toDouble(),
      packagingCost: (m['packagingCost'] as num).toDouble(),
      volumeCC: m['volumeCC'] as int?,
      isActive: m['isActive'] as bool? ?? true,
      sortOrder: m['sortOrder'] as int? ?? 0,
      updatedAt: m['updatedAt'] != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      history: (m['history'] as List?)?.map((h) => PackagingHistory(
        changedAt: DateTime.tryParse(h['changedAt'] as String? ?? '') ?? DateTime.now(),
        containerPrice: (h['containerPrice'] as num).toDouble(),
        packagingCost: (h['packagingCost'] as num).toDouble(),
        note: h['note'] as String? ?? '',
      )).toList() ?? [],
    );
  }

  static Map<String, dynamic> _packagingToMap(Packaging pkg) => {
    'id': pkg.id,
    'name': pkg.name,
    'category': pkg.category,
    'containerPrice': pkg.containerPrice,
    'packagingCost': pkg.packagingCost,
    'volumeCC': pkg.volumeCC,
    'isActive': pkg.isActive,
    'sortOrder': pkg.sortOrder,
    'updatedAt': pkg.updatedAt.toIso8601String(),
    'history': <Map<String, dynamic>>[],  // 히스토리는 서버에서 자동 관리
  };

  static Recipe _mapRecipe(Map<String, dynamic> m) {
    return Recipe(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      items: (m['items'] as List?)?.map((i) => RecipeItem(
        ingredientId: i['ingredientId'] as String,
        ingredientName: i['ingredientName'] as String? ?? '',
        ratio: (i['ratio'] as num).toDouble(),
      )).toList() ?? [],
      packagingId: m['packagingId'] as String? ?? '',
      packagingWeight: (m['packagingWeight'] as num?)?.toDouble() ?? 0,
      packagingType: m['packagingType'] as String? ?? 'vinyl',
      calculatedPrice: (m['calculatedPrice'] as num?)?.toDouble() ?? 0,
      customerNote: m['customerNote'] as String? ?? '',
      workerName: m['workerName'] as String? ?? '',
      weightCategory: m['weightCategory'] as String? ?? 'under100',
      bulkMoqKg: (m['bulkMoqKg'] as num?)?.toDouble() ?? 10.0,
      createdAt: m['createdAt'] != null ? DateTime.tryParse(m['createdAt'] as String) : null,
    );
  }

  static Map<String, dynamic> _recipeToMap(Recipe r) => {
    'id': r.id,
    'name': r.name,
    'items': r.items.map((i) => {
      'ingredientId': i.ingredientId,
      'ingredientName': i.ingredientName,
      'ratio': i.ratio,
    }).toList(),
    'packagingId': r.packagingId,
    'packagingWeight': r.packagingWeight,
    'packagingType': r.packagingType,
    'calculatedPrice': r.calculatedPrice,
    'customerNote': r.customerNote,
    'workerName': r.workerName,
    'weightCategory': r.weightCategory,
    'bulkMoqKg': r.bulkMoqKg,
    'createdAt': r.createdAt.toIso8601String(),
  };

  // ── 직원/고객 계정 API ──

  static Future<Map<String, dynamic>> registerAccount({
    required String name,
    required String pin,
    required String role, // 'staff' | 'customer'
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/staff/register'),
        headers: _headers,
        body: jsonEncode({'name': name, 'pin': pin, 'role': role}),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[CF] registerAccount error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> loginAccount({
    required String name,
    required String pin,
    required String role,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/staff/login'),
        headers: _headers,
        body: jsonEncode({'name': name, 'pin': pin, 'role': role}),
      ).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[CF] loginAccount error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingAccounts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/staff/pending'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CF] getPendingAccounts error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllAccounts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/staff/list'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CF] getAllAccounts error: $e');
    }
    return [];
  }

  static Future<bool> approveAccount(String id, {bool approve = true, String approvedBy = 'petsyndrome'}) async {
    try {
      final action = approve ? 'approve' : 'reject';
      final res = await http.post(
        Uri.parse('$baseUrl/api/staff/$id/$action'),
        headers: _headers,
        body: jsonEncode({'approvedBy': approvedBy}),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[CF] approveAccount error: $e');
      return false;
    }
  }

  static Future<bool> deleteAccount(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/api/staff/$id'), headers: _headers).timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[CF] deleteAccount error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getLoginLogs() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/logs'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CF] getLoginLogs error: $e');
    }
    return [];
  }

  // ── 이카운트 ERP 연동 ──
  static Future<Map<String, dynamic>> icountGetSession({
    required String companyCode,
    required String userId,
    required String apiCertKey,
    String zone = 'auto',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/icount/session'),
        headers: _headers,
        body: jsonEncode({
          'companyCode': companyCode,
          'userId': userId,
          'apiCertKey': apiCertKey,
          'zone': zone,
        }),
      ).timeout(_timeout);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CF] icountGetSession error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> icountSendEstimate({
    required String sessionId,
    required List<Map<String, dynamic>> items,
    String zone = '1',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/icount/estimate'),
        headers: _headers,
        body: jsonEncode({'sessionId': sessionId, 'zone': zone, 'estimateItems': items}),
      ).timeout(_timeout);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CF] icountSendEstimate error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> icountGetConfig() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/icount/config'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body == null ? null : body as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[CF] icountGetConfig error: $e');
    }
    return null;
  }

  static Future<bool> icountSaveConfig({
    required String companyCode,
    required String userId,
    required String apiCertKey,
    String zone = 'auto',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/icount/config'),
        headers: _headers,
        body: jsonEncode({
          'companyCode': companyCode,
          'userId': userId,
          'apiCertKey': apiCertKey,
          'zone': zone,
        }),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[CF] icountSaveConfig error: $e');
      return false;
    }
  }
}
