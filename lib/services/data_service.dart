import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ingredient.dart';
import '../models/work_cost.dart';
import '../models/packaging.dart';
import '../models/recipe.dart';
import 'cloudflare_service.dart';

/// DataService - 서버(Cloudflare Workers KV) 우선, 로컬 Hive 캐시 병행
/// 모든 기기에서 동일한 데이터를 공유합니다.
class DataService {
  static const _settingsBox = 'settings';
  static const _workerBox = 'workers';

  static final _uuid = const Uuid();

  // 인메모리 캐시 (서버에서 로드한 데이터)
  static List<Ingredient> _ingredients = [];
  static WorkCost? _workCost;
  static List<Packaging> _packagings = [];
  static List<Recipe> _recipes = [];

  static Future<void> init() async {
    await Hive.initFlutter();
    // 어댑터 중복 등록 방지
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(IngredientHistoryAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(IngredientAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(WorkCostHistoryAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkCostAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(PackagingHistoryAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PackagingAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(RecipeItemAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RecipeAdapter());

    await Hive.openBox(_settingsBox);
    await Hive.openBox(_workerBox);

    // 서버에서 전체 데이터 로드
    await refreshAll();
  }

  /// 서버에서 모든 데이터를 새로고침
  static Future<void> refreshAll() async {
    await Future.wait([
      _loadIngredients(),
      _loadWorkCost(),
      _loadPackagings(),
      _loadRecipes(),
    ]);
  }

  static Future<void> _loadIngredients() async {
    final list = await CloudflareService.getIngredients();
    if (list.isNotEmpty) {
      _ingredients = list;
    } else if (_ingredients.isEmpty) {
      _ingredients = _defaultIngredients();
    }
  }

  static Future<void> _loadWorkCost() async {
    final wc = await CloudflareService.getWorkCost();
    if (wc != null) {
      _workCost = wc;
    } else {
      _workCost ??= _defaultWorkCost();
    }
  }

  static Future<void> _loadPackagings() async {
    final list = await CloudflareService.getPackagings();
    if (list.isNotEmpty) {
      _packagings = list;
    } else if (_packagings.isEmpty) {
      _packagings = _defaultPackagings();
    }
  }

  static Future<void> _loadRecipes() async {
    final list = await CloudflareService.getRecipes();
    _recipes = list;
  }

  // ── 원물 ──

  static List<Ingredient> getIngredients({bool activeOnly = true}) {
    final list = activeOnly
        ? _ingredients.where((i) => i.isActive).toList()
        : List<Ingredient>.from(_ingredients);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<void> saveIngredient(Ingredient ing) async {
    ing.updatedAt = DateTime.now();
    // 히스토리는 서버(worker.js)에서 자동 관리 — 클라이언트는 현재 값만 전송
    ing.history = [];

    // 서버 저장
    final ok = await CloudflareService.saveIngredient(ing);
    debugPrint('[DataService] saveIngredient ${ing.name} → ok=$ok');

    // 캐시 업데이트
    final idx = _ingredients.indexWhere((i) => i.id == ing.id);
    if (idx >= 0) {
      _ingredients[idx] = ing;
    } else {
      _ingredients.add(ing);
    }
  }

  static Future<void> deleteIngredient(String id) async {
    await CloudflareService.deleteIngredient(id);
    _ingredients.removeWhere((i) => i.id == id);
  }

  static String generateId() => _uuid.v4();

  // ── 작업비 ──

  static WorkCost getWorkCost() {
    return _workCost ?? _defaultWorkCost();
  }

  static Future<void> saveWorkCost(WorkCost wc, {String changedBy = '관리자'}) async {
    final ok = await CloudflareService.saveWorkCost(wc, changedBy: changedBy);
    debugPrint('[DataService] saveWorkCost → ok=$ok');
    if (ok) _workCost = wc;
  }

  // ── 포장 ──

  static List<Packaging> getPackagings({bool activeOnly = true}) {
    final list = activeOnly
        ? _packagings.where((p) => p.isActive).toList()
        : List<Packaging>.from(_packagings);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  static Future<void> savePackaging(Packaging pkg) async {
    final ok = await CloudflareService.savePackaging(pkg);
    debugPrint('[DataService] savePackaging ${pkg.name} → ok=$ok');

    if (ok) {
      final idx = _packagings.indexWhere((p) => p.id == pkg.id);
      if (idx >= 0) {
        _packagings[idx] = pkg;
      } else {
        _packagings.add(pkg);
      }
    }
  }

  static Future<void> deletePackaging(String id) async {
    await CloudflareService.deletePackaging(id);
    _packagings.removeWhere((p) => p.id == id);
  }

  // ── 레시피 ──

  static List<Recipe> getRecipes({String? workerName}) {
    var list = List<Recipe>.from(_recipes);
    if (workerName != null && workerName.isNotEmpty) {
      list = list.where((r) => r.workerName == workerName).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> saveRecipe(Recipe recipe) async {
    await CloudflareService.saveRecipe(recipe);
    _recipes.removeWhere((r) => r.id == recipe.id);
    _recipes.add(recipe);
  }

  static Future<void> deleteRecipe(String id) async {
    await CloudflareService.deleteRecipe(id);
    _recipes.removeWhere((r) => r.id == id);
  }

  // ── 관리자 인증 (로컬) ──

  static bool checkLogin(String id, String pw) {
    return id == 'petsyndrome' && pw == 'a29251313';
  }

  static bool get isLoggedIn => Hive.box(_settingsBox).get('loggedIn') == true;
  static Future<void> setLoggedIn(bool v) async => Hive.box(_settingsBox).put('loggedIn', v);

  // ── 작업자 인증 (로컬) ──

  static Box get workerBox => Hive.box(_workerBox);

  static Future<void> registerWorker(String name, String pin) async {
    await workerBox.put('worker_$name', {
      'name': name,
      'pin': pin,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static bool checkWorkerLogin(String name, String pin) {
    final data = workerBox.get('worker_$name');
    if (data == null) return false;
    return data['pin'] == pin;
  }

  static List<String> getWorkerNames() {
    return workerBox.keys
        .where((k) => k.toString().startsWith('worker_'))
        .map((k) => (workerBox.get(k) as Map)['name'] as String)
        .toList();
  }

  static String get currentWorker =>
      Hive.box(_settingsBox).get('currentWorker') as String? ?? '';
  static Future<void> setCurrentWorker(String name) async =>
      Hive.box(_settingsBox).put('currentWorker', name);
  static Future<void> clearCurrentWorker() async =>
      Hive.box(_settingsBox).delete('currentWorker');

  // ── 기본값 ──

  static WorkCost _defaultWorkCost() => WorkCost(
        id: 'default',
        dryingCost: 2000,
        mixingCost: 1000,
        cuttingCost: 1000,
        cuttingLossRate: 0.05,
        marginRate: 0.30,
      );

  static List<Ingredient> _defaultIngredients() => [];

  static List<Packaging> _defaultPackagings() => [];
}
