import '../models/ingredient.dart';
import '../models/work_cost.dart';
import '../models/packaging.dart';
import '../models/recipe.dart';

class CostResult {
  final double rawCostPerKg;      // 원물 원가 (원/kg)
  final double totalCostPerKg;    // 총 원가 (원/kg)
  final double unitPricePerKg;    // 단가 마진 포함 (원/kg)
  final double unitPricePerPack;  // 포장당 단가 (원)
  final double packagingCostPerPack; // 포장비 합계 (원)
  final String formula;           // 사용된 공식 설명 (요약)
  final String detailedFormula;   // 숫자 대입 상세 수식 (클릭 시 표시)
  final List<String> formulaSteps; // 단계별 계산식 목록

  CostResult({
    required this.rawCostPerKg,
    required this.totalCostPerKg,
    required this.unitPricePerKg,
    required this.unitPricePerPack,
    required this.packagingCostPerPack,
    required this.formula,
    this.detailedFormula = '',
    this.formulaSteps = const [],
  });
}

class CostCalculator {
  // 기본 최종 로스율 3% (마진율과 별도로 항상 적용)
  static const double defaultFinalLossRate = 0.03;

  /// 단미 원가 계산
  /// 공식: (((원물가격+절단비)/(1-절단로스율)+건조비)/(1-수분)) / (1-마진율) / (1-최종로스율)
  /// 최종로스율: 기본 3% 고정
  static double calcSingleRawCostPerKg({
    required double unitPrice,   // 원물가격 (원/kg)
    required double moisture,    // 수분율 (0~1)
    required WorkCost wc,
    double finalLossRate = defaultFinalLossRate,
  }) {
    // Step1: (원물가+절단비) / (1 - 절단로스율)
    final step1 = (unitPrice + wc.cuttingCost) / (1 - wc.cuttingLossRate);
    // Step2: (Step1 + 건조비) / (1 - 수분율)
    final step2 = (step1 + wc.dryingCost) / (1 - moisture);
    // Step3: Step2 / (1 - 마진율)  → 마진 포함
    final step3 = step2 / (1 - wc.marginRate);
    // Step4: Step3 / (1 - 최종로스율 3%) → 최종 로스 반영
    final step4 = step3 / (1 - finalLossRate);
    return step4;
  }

  static double applyMargin(double cost, double marginRate) {
    return cost / (1 - marginRate);
  }

  /// 배합 원가 계산 (여러 원물 혼합)
  /// 원물별 비율 가중 평균으로 원물가·수분율 계산
  /// 공식: (((가중평균원물가+배합비+절단비)/(1-절단로스율)+건조비)/(1-가중평균수분)) / (1-마진율) / (1-최종로스율)
  static double calcMixedRawCostPerKg({
    required List<RecipeItem> items,
    required List<Ingredient> ingredients,
    required WorkCost wc,
    double finalLossRate = defaultFinalLossRate,
  }) {
    double totalWeightedCost = 0;
    double totalWeightedMoisture = 0;
    double totalRatio = 0;

    for (final item in items) {
      final ing = ingredients.where((i) => i.id == item.ingredientId).firstOrNull;
      if (ing == null) continue;

      final ratio = item.ratio / 100.0;
      totalWeightedCost += ing.unitPrice * ratio;
      totalWeightedMoisture += ing.moisture * ratio;
      totalRatio += ratio;
    }

    if (totalRatio == 0) return 0;

    final avgPrice = totalWeightedCost / totalRatio;
    final avgMoisture = totalWeightedMoisture / totalRatio;

    // Step1: (가중평균원물가+배합작업비+절단비) / (1-절단로스율)
    final step1 = (avgPrice + wc.mixingCost + wc.cuttingCost) / (1 - wc.cuttingLossRate);
    // Step2: (Step1+건조비) / (1-가중평균수분율)
    final step2 = (step1 + wc.dryingCost) / (1 - avgMoisture);
    // Step3: Step2 / (1-마진율)
    final step3 = step2 / (1 - wc.marginRate);
    // Step4: Step3 / (1-최종로스율 3%)
    final step4 = step3 / (1 - finalLossRate);
    return step4;
  }

  /// 최종 포장당 단가 계산
  static CostResult calculate({
    required List<RecipeItem> items,
    required List<Ingredient> allIngredients,
    required WorkCost wc,
    required Packaging packaging,
    required double packagingWeightG, // 포장중량 (g)
    required bool isMixed,
  }) {
    double unitPricePerKg;
    String formula;

    String detailedFormula = '';
    List<String> formulaSteps = [];

    if (!isMixed && items.length == 1) {
      final ing = allIngredients.where((i) => i.id == items[0].ingredientId).firstOrNull;
      if (ing == null) {
        return CostResult(rawCostPerKg: 0, totalCostPerKg: 0, unitPricePerKg: 0, unitPricePerPack: 0, packagingCostPerPack: 0, formula: '원물 없음');
      }
      unitPricePerKg = calcSingleRawCostPerKg(
        unitPrice: ing.unitPrice,
        moisture: ing.moisture,
        wc: wc,
      );
      formula = '단미: (((원물가+절단비)/(1-로스율)+건조비)/(1-수분))/(1-마진율)/(1-3%)';

      // 단계별 상세 계산
      final s1 = (ing.unitPrice + wc.cuttingCost) / (1 - wc.cuttingLossRate);
      final s2 = (s1 + wc.dryingCost) / (1 - ing.moisture);
      final s3 = s2 / (1 - wc.marginRate);
      final s4 = s3 / (1 - defaultFinalLossRate);
      formulaSteps = [
        '① 절단 후 원물가\n   (${ing.unitPrice.toStringAsFixed(0)} + ${wc.cuttingCost.toStringAsFixed(0)}) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)\n   = ${s1.toStringAsFixed(1)}원/kg',
        '② 건조 후 원가\n   (${s1.toStringAsFixed(1)} + ${wc.dryingCost.toStringAsFixed(0)}) ÷ (1 - ${(ing.moisture*100).toStringAsFixed(1)}%수분)\n   = ${s2.toStringAsFixed(1)}원/kg',
        '③ 마진 적용 (${(wc.marginRate*100).toStringAsFixed(1)}%)\n   ${s2.toStringAsFixed(1)} ÷ (1 - ${(wc.marginRate*100).toStringAsFixed(1)}%)\n   = ${s3.toStringAsFixed(1)}원/kg',
        '④ 최종로스 3% 적용\n   ${s3.toStringAsFixed(1)} ÷ (1 - 3%)\n   = ${s4.toStringAsFixed(1)}원/kg ← 최종단가',
      ];
      detailedFormula = '단미 원가 계산 (${ing.name})\n\n원물가: ${ing.unitPrice.toStringAsFixed(0)}원/kg | 수분: ${(ing.moisture*100).toStringAsFixed(1)}% | 절단비: ${wc.cuttingCost.toStringAsFixed(0)}원 | 건조비: ${wc.dryingCost.toStringAsFixed(0)}원 | 절단로스: ${(wc.cuttingLossRate*100).toStringAsFixed(1)}% | 마진: ${(wc.marginRate*100).toStringAsFixed(1)}%';
    } else {
      unitPricePerKg = calcMixedRawCostPerKg(
        items: items,
        ingredients: allIngredients,
        wc: wc,
      );
      formula = '배합: 원물별 가중평균(원물가·수분율) + 배합비/절단비 → 마진율(${wc.marginRate*100}%) + 최종로스(3%) 적용';

      // 배합 상세 계산
      double totalWeightedCost = 0, totalWeightedMoisture = 0, totalRatio = 0;
      for (final item in items) {
        final ing = allIngredients.where((i) => i.id == item.ingredientId).firstOrNull;
        if (ing == null) continue;
        final ratio = item.ratio / 100.0;
        totalWeightedCost += ing.unitPrice * ratio;
        totalWeightedMoisture += ing.moisture * ratio;
        totalRatio += ratio;
      }
      if (totalRatio > 0) {
        final avgPrice = totalWeightedCost / totalRatio;
        final avgMoisture = totalWeightedMoisture / totalRatio;
        final ms1 = (avgPrice + wc.mixingCost + wc.cuttingCost) / (1 - wc.cuttingLossRate);
        final ms2 = (ms1 + wc.dryingCost) / (1 - avgMoisture);
        final ms3 = ms2 / (1 - wc.marginRate);
        final ms4 = ms3 / (1 - defaultFinalLossRate);
        formulaSteps = [
          '① 원물 가중평균\n   원물가: ${avgPrice.toStringAsFixed(1)}원/kg\n   수분율: ${(avgMoisture*100).toStringAsFixed(1)}%',
          '② 절단 후 원물가\n   (${avgPrice.toStringAsFixed(1)} + ${wc.mixingCost.toStringAsFixed(0)}배합비 + ${wc.cuttingCost.toStringAsFixed(0)}절단비) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)\n   = ${ms1.toStringAsFixed(1)}원/kg',
          '③ 건조 후 원가\n   (${ms1.toStringAsFixed(1)} + ${wc.dryingCost.toStringAsFixed(0)}건조비) ÷ (1 - ${(avgMoisture*100).toStringAsFixed(1)}%수분)\n   = ${ms2.toStringAsFixed(1)}원/kg',
          '④ 마진 적용 (${(wc.marginRate*100).toStringAsFixed(1)}%)\n   ${ms2.toStringAsFixed(1)} ÷ (1 - ${(wc.marginRate*100).toStringAsFixed(1)}%)\n   = ${ms3.toStringAsFixed(1)}원/kg',
          '⑤ 최종로스 3% 적용\n   ${ms3.toStringAsFixed(1)} ÷ (1 - 3%)\n   = ${ms4.toStringAsFixed(1)}원/kg ← 최종단가',
        ];
      }
      detailedFormula = '배합 원가 계산\n\n절단비: ${wc.cuttingCost.toStringAsFixed(0)}원 | 건조비: ${wc.dryingCost.toStringAsFixed(0)}원 | 배합비: ${wc.mixingCost.toStringAsFixed(0)}원 | 절단로스: ${(wc.cuttingLossRate*100).toStringAsFixed(1)}% | 마진: ${(wc.marginRate*100).toStringAsFixed(1)}%';
    }

    final weightKg = packagingWeightG / 1000.0;
    final packagingCostPerPack = packaging.containerPrice + packaging.packagingCost;
    final unitPricePerPack = (unitPricePerKg * weightKg) + packagingCostPerPack;

    return CostResult(
      rawCostPerKg: unitPricePerKg,
      totalCostPerKg: unitPricePerKg,
      unitPricePerKg: unitPricePerKg,
      unitPricePerPack: unitPricePerPack,
      packagingCostPerPack: packagingCostPerPack,
      formula: formula,
      detailedFormula: detailedFormula,
      formulaSteps: formulaSteps,
    );
  }

  /// 영양 성분 계산 (배합 시 가중 평균)
  static Map<String, double?> calcNutrition({
    required List<RecipeItem> items,
    required List<Ingredient> allIngredients,
  }) {
    if (items.isEmpty) return {};

    double totalRatio = 0;
    double protein = 0, fat = 0, ash = 0, fiber = 0, calcium = 0, phosphorus = 0, moisture = 0;
    bool hasProtein = false, hasFat = false, hasAsh = false, hasFiber = false;
    bool hasCalcium = false, hasPhosphorus = false;

    for (final item in items) {
      final ing = allIngredients.where((i) => i.id == item.ingredientId).firstOrNull;
      if (ing == null) continue;
      final r = item.ratio / 100.0;
      totalRatio += r;
      moisture += ing.moisture * r;
      if (ing.crudeProtein != null) { protein += ing.crudeProtein! * r; hasProtein = true; }
      if (ing.crudeFat != null) { fat += ing.crudeFat! * r; hasFat = true; }
      if (ing.crudeAsh != null) { ash += ing.crudeAsh! * r; hasAsh = true; }
      if (ing.crudeFiber != null) { fiber += ing.crudeFiber! * r; hasFiber = true; }
      if (ing.calcium != null) { calcium += ing.calcium! * r; hasCalcium = true; }
      if (ing.phosphorus != null) { phosphorus += ing.phosphorus! * r; hasPhosphorus = true; }
    }

    if (totalRatio == 0) return {};

    return {
      'moisture': moisture / totalRatio,
      'crudeProtein': hasProtein ? protein / totalRatio : null,
      'crudeFat': hasFat ? fat / totalRatio : null,
      'crudeAsh': hasAsh ? ash / totalRatio : null,
      'crudeFiber': hasFiber ? fiber / totalRatio : null,
      'calcium': hasCalcium ? calcium / totalRatio : null,
      'phosphorus': hasPhosphorus ? phosphorus / totalRatio : null,
    };
  }
}
