import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ingredient.dart';
import '../models/work_cost.dart';
import '../models/packaging.dart';
import '../models/recipe.dart';

class DataService {
  static const _ingredientBox = 'ingredients';
  static const _workCostBox = 'work_costs';
  static const _packagingBox = 'packagings';
  static const _recipeBox = 'recipes';
  static const _settingsBox = 'settings';
  static const _workerBox = 'workers'; // 작업자 계정

  static final _uuid = const Uuid();

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(IngredientHistoryAdapter());
    Hive.registerAdapter(IngredientAdapter());
    Hive.registerAdapter(WorkCostHistoryAdapter());
    Hive.registerAdapter(WorkCostAdapter());
    Hive.registerAdapter(PackagingHistoryAdapter());
    Hive.registerAdapter(PackagingAdapter());
    Hive.registerAdapter(RecipeItemAdapter());
    Hive.registerAdapter(RecipeAdapter());

    await Hive.openBox<Ingredient>(_ingredientBox);
    await Hive.openBox<WorkCost>(_workCostBox);
    await Hive.openBox<Packaging>(_packagingBox);
    await Hive.openBox<Recipe>(_recipeBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_workerBox);

    await _seedDefaultData();
  }

  static Future<void> _seedDefaultData() async {
    final settings = Hive.box(_settingsBox);
    if (settings.get('seeded_v2') == true) return;

    // 기본 원물 데이터
    final ingredients = [
      Ingredient(id: _uuid.v4(), name: '닭가슴살', type: 'raw', unitPrice: 3500, moisture: 0.75, crudeProtein: 23.0, crudeFat: 1.2, crudeAsh: 1.1, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.2),
      Ingredient(id: _uuid.v4(), name: '연어', type: 'raw', unitPrice: 8000, moisture: 0.70, crudeProtein: 20.0, crudeFat: 13.0, crudeAsh: 1.3, crudeFiber: 0.0, calcium: 0.02, phosphorus: 0.25),
      Ingredient(id: _uuid.v4(), name: '북어', type: 'raw', unitPrice: 12000, moisture: 0.15, crudeProtein: 80.0, crudeFat: 1.0, crudeAsh: 5.0, crudeFiber: 0.0, calcium: 0.15, phosphorus: 0.8),
      Ingredient(id: _uuid.v4(), name: '명태', type: 'raw', unitPrice: 4500, moisture: 0.80, crudeProtein: 17.0, crudeFat: 0.5, crudeAsh: 1.2, crudeFiber: 0.0, calcium: 0.05, phosphorus: 0.2),
      Ingredient(id: _uuid.v4(), name: '열빙어', type: 'raw', unitPrice: 3000, moisture: 0.78, crudeProtein: 15.0, crudeFat: 3.0, crudeAsh: 2.0, crudeFiber: 0.0, calcium: 0.3, phosphorus: 0.25),
      Ingredient(id: _uuid.v4(), name: '산양유', type: 'raw', unitPrice: 15000, moisture: 0.87, crudeProtein: 3.5, crudeFat: 4.0, crudeAsh: 0.8, crudeFiber: 0.0, calcium: 0.13, phosphorus: 0.1),
      Ingredient(id: _uuid.v4(), name: '치즈', type: 'raw', unitPrice: 18000, moisture: 0.40, crudeProtein: 25.0, crudeFat: 30.0, crudeAsh: 4.0, crudeFiber: 0.0, calcium: 0.7, phosphorus: 0.5),
      Ingredient(id: _uuid.v4(), name: '고구마', type: 'raw', unitPrice: 2000, moisture: 0.68, crudeProtein: 1.6, crudeFat: 0.1, crudeAsh: 0.9, crudeFiber: 3.0, calcium: 0.03, phosphorus: 0.05),
      Ingredient(id: _uuid.v4(), name: '단호박', type: 'raw', unitPrice: 1800, moisture: 0.91, crudeProtein: 1.0, crudeFat: 0.1, crudeAsh: 0.6, crudeFiber: 2.7, calcium: 0.02, phosphorus: 0.04),
      Ingredient(id: _uuid.v4(), name: '브로콜리', type: 'raw', unitPrice: 2500, moisture: 0.90, crudeProtein: 2.8, crudeFat: 0.4, crudeAsh: 0.9, crudeFiber: 2.6, calcium: 0.05, phosphorus: 0.07),
      Ingredient(id: _uuid.v4(), name: '소고기', type: 'raw', unitPrice: 12000, moisture: 0.70, crudeProtein: 21.0, crudeFat: 8.0, crudeAsh: 1.0, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.2),
      Ingredient(id: _uuid.v4(), name: '오리고기', type: 'raw', unitPrice: 5500, moisture: 0.72, crudeProtein: 19.0, crudeFat: 6.0, crudeAsh: 1.1, crudeFiber: 0.0, calcium: 0.01, phosphorus: 0.18),
    ];

    final ingBox = Hive.box<Ingredient>(_ingredientBox);
    // 기존 데이터가 없을 때만 추가
    if (ingBox.isEmpty) {
      for (final ing in ingredients) {
        await ingBox.put(ing.id, ing);
      }
    }

    // 기본 작업비
    final wcBox = Hive.box<WorkCost>(_workCostBox);
    if (wcBox.get('default') == null) {
      final workCost = WorkCost(
        id: 'default',
        dryingCost: 2000,
        mixingCost: 1000,
        cuttingCost: 1000,
        cuttingLossRate: 0.05,
        marginRate: 0.30,
      );
      await wcBox.put('default', workCost);
    }

    // 기본 포장 데이터
    final pkgBox = Hive.box<Packaging>(_packagingBox);
    if (pkgBox.isEmpty) {
      final packagings = [
        Packaging(id: _uuid.v4(), name: '비닐포장', category: 'vinyl', containerPrice: 50, packagingCost: 200, sortOrder: 0),
        Packaging(id: _uuid.v4(), name: '샘플포장', category: 'sample', containerPrice: 30, packagingCost: 150, sortOrder: 1),
        Packaging(id: _uuid.v4(), name: '300cc 통', category: 'container', containerPrice: 800, packagingCost: 500, volumeCC: 300, sortOrder: 2),
        Packaging(id: _uuid.v4(), name: '400cc 통', category: 'container', containerPrice: 900, packagingCost: 550, volumeCC: 400, sortOrder: 3),
        Packaging(id: _uuid.v4(), name: '500cc 통', category: 'container', containerPrice: 1000, packagingCost: 600, volumeCC: 500, sortOrder: 4),
        Packaging(id: _uuid.v4(), name: '600cc 통', category: 'container', containerPrice: 1100, packagingCost: 650, volumeCC: 600, sortOrder: 5),
        Packaging(id: _uuid.v4(), name: '700cc 통', category: 'container', containerPrice: 1200, packagingCost: 700, volumeCC: 700, sortOrder: 6),
        Packaging(id: _uuid.v4(), name: '1000cc 통', category: 'container', containerPrice: 1500, packagingCost: 800, volumeCC: 1000, sortOrder: 7),
        Packaging(id: _uuid.v4(), name: '1200cc 통', category: 'container', containerPrice: 1700, packagingCost: 900, volumeCC: 1200, sortOrder: 8),
        Packaging(id: _uuid.v4(), name: '1500cc 통', category: 'container', containerPrice: 2000, packagingCost: 1000, volumeCC: 1500, sortOrder: 9),
      ];
      for (final pkg in packagings) {
        await pkgBox.put(pkg.id, pkg);
      }
    }

    await settings.put('seeded_v2', true);
  }

  // ── 원물 ──
  static Box<Ingredient> get ingredientBox => Hive.box<Ingredient>(_ingredientBox);
  static List<Ingredient> getIngredients({bool activeOnly = true}) {
    final all = ingredientBox.values.toList();
    if (activeOnly) return all.where((i) => i.isActive).toList()..sort((a, b) => a.name.compareTo(b.name));
    return all..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> saveIngredient(Ingredient ing) async {
    final existing = ingredientBox.get(ing.id);
    if (existing != null && (existing.unitPrice != ing.unitPrice || existing.moisture != ing.moisture)) {
      ing.history = List<IngredientHistory>.from(existing.history)
        ..add(IngredientHistory(
          changedAt: existing.updatedAt,
          unitPrice: existing.unitPrice,
          moisture: existing.moisture,
          note: '단가: ${existing.unitPrice.toStringAsFixed(0)}→${ing.unitPrice.toStringAsFixed(0)}, 수분: ${(existing.moisture*100).toStringAsFixed(1)}%→${(ing.moisture*100).toStringAsFixed(1)}%',
        ));
    } else if (existing != null) {
      ing.history = List<IngredientHistory>.from(existing.history);
    }
    ing.updatedAt = DateTime.now();
    await ingredientBox.put(ing.id, ing);
  }

  static Future<void> deleteIngredient(String id) async {
    await ingredientBox.delete(id);
  }

  // ── 작업비 ──
  static Box<WorkCost> get workCostBox => Hive.box<WorkCost>(_workCostBox);
  static WorkCost getWorkCost() {
    return workCostBox.get('default') ??
        WorkCost(id: 'default', dryingCost: 2000, mixingCost: 1000, cuttingCost: 1000, cuttingLossRate: 0.05, marginRate: 0.30);
  }

  static Future<void> saveWorkCost(WorkCost wc, {String changedBy = '관리자'}) async {
    final existing = workCostBox.get('default');
    if (existing != null) {
      // 변경사항 감지해 이력 추가
      final changes = <String>[];
      if (existing.dryingCost != wc.dryingCost) changes.add('건조비: ${existing.dryingCost.toStringAsFixed(0)}→${wc.dryingCost.toStringAsFixed(0)}원');
      if (existing.mixingCost != wc.mixingCost) changes.add('배합비: ${existing.mixingCost.toStringAsFixed(0)}→${wc.mixingCost.toStringAsFixed(0)}원');
      if (existing.cuttingCost != wc.cuttingCost) changes.add('절단비: ${existing.cuttingCost.toStringAsFixed(0)}→${wc.cuttingCost.toStringAsFixed(0)}원');
      if (existing.cuttingLossRate != wc.cuttingLossRate) changes.add('절단로스: ${(existing.cuttingLossRate*100).toStringAsFixed(1)}%→${(wc.cuttingLossRate*100).toStringAsFixed(1)}%');
      if (existing.marginRate != wc.marginRate) changes.add('마진율: ${(existing.marginRate*100).toStringAsFixed(1)}%→${(wc.marginRate*100).toStringAsFixed(1)}%');

      if (changes.isNotEmpty) {
        wc.history = List<WorkCostHistory>.from(existing.history)
          ..add(WorkCostHistory(
            changedAt: existing.updatedAt,
            dryingCost: existing.dryingCost,
            mixingCost: existing.mixingCost,
            cuttingCost: existing.cuttingCost,
            cuttingLossRate: existing.cuttingLossRate,
            marginRate: existing.marginRate,
            note: changes.join(', '),
            changedBy: changedBy,
          ));
      } else {
        wc.history = List<WorkCostHistory>.from(existing.history);
      }
    }
    wc.changedBy = changedBy;
    wc.updatedAt = DateTime.now();
    await workCostBox.put('default', wc);
  }

  // ── 포장 ──
  static Box<Packaging> get packagingBox => Hive.box<Packaging>(_packagingBox);
  static List<Packaging> getPackagings({bool activeOnly = true}) {
    final all = packagingBox.values.toList();
    if (activeOnly) return all.where((p) => p.isActive).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return all..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static Future<void> savePackaging(Packaging pkg) async {
    final existing = packagingBox.get(pkg.id);
    if (existing != null) {
      final changes = <String>[];
      if (existing.containerPrice != pkg.containerPrice) changes.add('통가격: ${existing.containerPrice.toStringAsFixed(0)}→${pkg.containerPrice.toStringAsFixed(0)}원');
      if (existing.packagingCost != pkg.packagingCost) changes.add('포장비: ${existing.packagingCost.toStringAsFixed(0)}→${pkg.packagingCost.toStringAsFixed(0)}원');
      if (existing.name != pkg.name) changes.add('품목명: ${existing.name}→${pkg.name}');

      if (changes.isNotEmpty) {
        pkg.history = List<PackagingHistory>.from(existing.history)
          ..add(PackagingHistory(
            changedAt: existing.updatedAt,
            containerPrice: existing.containerPrice,
            packagingCost: existing.packagingCost,
            note: changes.join(', '),
          ));
      } else {
        pkg.history = List<PackagingHistory>.from(existing.history);
      }
    }
    pkg.updatedAt = DateTime.now();
    await packagingBox.put(pkg.id, pkg);
  }

  static Future<void> deletePackaging(String id) async {
    await packagingBox.delete(id);
  }

  // ── 레시피 ──
  static Box<Recipe> get recipeBox => Hive.box<Recipe>(_recipeBox);
  static List<Recipe> getRecipes({String? workerName}) {
    var list = recipeBox.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (workerName != null && workerName.isNotEmpty) {
      list = list.where((r) => r.workerName == workerName).toList();
    }
    return list;
  }

  static Future<void> saveRecipe(Recipe recipe) async {
    await recipeBox.put(recipe.id, recipe);
  }

  static Future<void> deleteRecipe(String id) async {
    await recipeBox.delete(id);
  }

  // ── 관리자 인증 ──
  static bool checkLogin(String id, String pw) {
    return id == 'petsyndrome' && pw == 'a29251313';
  }

  static bool get isLoggedIn => Hive.box(_settingsBox).get('loggedIn') == true;
  static Future<void> setLoggedIn(bool v) async => Hive.box(_settingsBox).put('loggedIn', v);

  // ── 작업자 인증 ──
  static Box get workerBox => Hive.box(_workerBox);

  /// 작업자 등록 (관리자 백엔드에서 등록)
  static Future<void> registerWorker(String name, String pin) async {
    await workerBox.put('worker_$name', {'name': name, 'pin': pin, 'createdAt': DateTime.now().toIso8601String()});
  }

  /// 작업자 로그인 확인
  static bool checkWorkerLogin(String name, String pin) {
    final data = workerBox.get('worker_$name');
    if (data == null) return false;
    return data['pin'] == pin;
  }

  /// 등록된 작업자 목록
  static List<String> getWorkerNames() {
    return workerBox.keys
        .where((k) => k.toString().startsWith('worker_'))
        .map((k) => (workerBox.get(k) as Map)['name'] as String)
        .toList();
  }

  /// 현재 로그인된 작업자 (세션)
  static String get currentWorker => Hive.box(_settingsBox).get('currentWorker') as String? ?? '';
  static Future<void> setCurrentWorker(String name) async => Hive.box(_settingsBox).put('currentWorker', name);
  static Future<void> clearCurrentWorker() async => Hive.box(_settingsBox).delete('currentWorker');
}
