import 'package:flutter/material.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../services/cost_calculator.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});
  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  String _search = '';

  List<Recipe> get _recipes {
    var list = DataService.getRecipes();
    if (_search.isNotEmpty) {
      list = list
          .where((r) =>
              r.name.contains(_search) ||
              r.workerName.contains(_search) ||
              r.items.any((it) => it.ingredientName.contains(_search)))
          .toList();
    }
    return list;
  }

  Future<bool> _confirmDelete(Recipe r) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '${r.isSingleIngredient ? "단미" : "혼합"} 견적 기록을 삭제하시겠습니까?\n\n원료: ${r.items.map((i) => i.ingredientName).join(", ")}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _delete(Recipe r) async {
    final confirmed = await _confirmDelete(r);
    if (!confirmed) return;
    if (!mounted) return;
    await DataService.deleteRecipe(r.id);
    if (!mounted) return;
    setState(() {});
  }

  void _showDetail(Recipe r) {
    final ingredients = DataService.getIngredients();
    final wc = DataService.getWorkCost();
    showDialog(
      context: context,
      builder: (_) => _RecipeDetailDialog(
        recipe: r,
        ingredients: ingredients,
        wc: wc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('단가 견적 이력'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '원료명, 작업자명으로 검색...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 요약 바
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('총 ${recipes.length}건',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Text('단미 ${recipes.where((r) => r.isSingleIngredient).length}건',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                const SizedBox(width: 8),
                Text('혼합 ${recipes.where((r) => !r.isSingleIngredient).length}건',
                    style: const TextStyle(fontSize: 11, color: AppTheme.warning)),
                const Spacer(),
                const Icon(Icons.touch_app_outlined,
                    size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                const Text('카드 클릭 시 원가 세부 내역',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: recipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          _search.isNotEmpty
                              ? '검색 결과가 없습니다.'
                              : '저장된 견적 이력이 없습니다.',
                          style: AppText.bodySmall,
                        ),
                        if (_search.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '고객 페이지에서 견적 계산 시 자동 저장됩니다.',
                              style: AppText.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = recipes[i];
                      return _RecipeCard(
                        recipe: r,
                        index: recipes.length - i,
                        onTap: () => _showDetail(r),
                        onDelete: () => _delete(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 레시피 카드 ──
class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecipeCard({
    required this.recipe,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  String _catLabel(String cat) {
    switch (cat) {
      case 'over100': return '100g이상';
      case 'bulk': return '벌크';
      default: return '100g이하';
    }
  }

  String _pkgLabel(String pkg) {
    switch (pkg) {
      case 'container': return '통포장';
      case 'sample': return '샘플';
      default: return '비닐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(13)),
                child: Center(
                    child: Text('$index',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600))),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(recipe.name,
                      style: AppText.heading3,
                      overflow: TextOverflow.ellipsis)),
              Text(Fmt.won(recipe.calculatedPrice), style: AppText.price),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.danger),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _Tag(recipe.isSingleIngredient ? '단미' : '혼합',
                  color: recipe.isSingleIngredient
                      ? AppTheme.primary
                      : AppTheme.warning),
              _Tag(_catLabel(recipe.weightCategory)),
              _Tag(_pkgLabel(recipe.packagingType)),
              if (recipe.weightCategory == 'bulk')
                _Tag('MOQ: ${recipe.bulkMoqKg.toStringAsFixed(0)}kg',
                    color: AppTheme.warning),
              if (recipe.workerName.isNotEmpty)
                _Tag('작업자: ${recipe.workerName}', color: AppTheme.info),
            ]),
            const SizedBox(height: 6),
            Text(
              recipe.items
                  .map((it) =>
                      '${it.ingredientName}(${it.ratio.toStringAsFixed(1)}%)')
                  .join(' + '),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time,
                  size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(Fmt.datetime(recipe.createdAt), style: AppText.bodySmall),
              const Spacer(),
              // 클릭 유도 힌트
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(children: [
                  Icon(Icons.calculate_outlined,
                      size: 10, color: AppTheme.primary),
                  SizedBox(width: 3),
                  Text('원가 상세',
                      style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const _Tag(this.text, {this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: c, fontWeight: FontWeight.w500)),
    );
  }
}

// ══════════════════════════════════════════════════
// 상세 다이얼로그 (원가 계산식 포함)
// ══════════════════════════════════════════════════
class _RecipeDetailDialog extends StatelessWidget {
  final Recipe recipe;
  final List<Ingredient> ingredients;
  final dynamic wc; // WorkCost

  const _RecipeDetailDialog({
    required this.recipe,
    required this.ingredients,
    required this.wc,
  });

  String _catLabel(String cat) {
    switch (cat) {
      case 'over100': return '100g 이상';
      case 'bulk': return '벌크(KG)';
      default: return '100g 이하';
    }
  }

  String _pkgLabel(String pkg) {
    switch (pkg) {
      case 'container': return '통포장';
      case 'sample': return '샘플포장';
      default: return '비닐포장';
    }
  }

  // ── 단미 계산 단계 ──
  _SingleCalc _calcSingle() {
    final item = recipe.items.first;
    final ing = ingredients.where((i) => i.id == item.ingredientId).firstOrNull;
    if (ing == null) return _SingleCalc.empty();

    final s1 = (ing.unitPrice + wc.cuttingCost) / (1 - wc.cuttingLossRate);
    final s2 = (s1 + wc.dryingCost) / (1 - ing.moisture);
    final s3 = s2 / (1 - wc.marginRate);
    final s4 = s3 / (1 - CostCalculator.defaultFinalLossRate);

    final weightKg = recipe.packagingWeight / 1000.0;
    // 포장비: 저장된 최종가에서 역산 (포장비=통값+포장작업비, 통은 packagingId로 조회 어려우므로 총가격-kg원가*kg으로 역산)
    final kgCostPart = s4 * weightKg;
    final pkgCostPart = recipe.calculatedPrice - kgCostPart;

    return _SingleCalc(ing: ing, s1: s1, s2: s2, s3: s3, s4: s4,
        kgCostPart: kgCostPart, pkgCostPart: pkgCostPart);
  }

  // ── 혼합 계산 단계 ──
  _MixedCalc _calcMixed() {
    double totalWeightedCost = 0, totalWeightedMoisture = 0, totalRatio = 0;
    final ingDetails = <_IngLine>[];

    for (final item in recipe.items) {
      final ing = ingredients.where((i) => i.id == item.ingredientId).firstOrNull;
      final ratio = item.ratio / 100.0;
      if (ing != null) {
        totalWeightedCost += ing.unitPrice * ratio;
        totalWeightedMoisture += ing.moisture * ratio;
        ingDetails.add(_IngLine(
          name: item.ingredientName,
          ratio: item.ratio,
          unitPrice: ing.unitPrice,
          moisture: ing.moisture,
          weightedCost: ing.unitPrice * ratio,
        ));
      } else {
        ingDetails.add(_IngLine(
          name: item.ingredientName,
          ratio: item.ratio,
          unitPrice: 0,
          moisture: 0,
          weightedCost: 0,
        ));
      }
      totalRatio += ratio;
    }

    if (totalRatio == 0) return _MixedCalc.empty();

    final avgPrice = totalWeightedCost / totalRatio;
    final avgMoisture = totalWeightedMoisture / totalRatio;
    final ms1 = (avgPrice + wc.mixingCost + wc.cuttingCost) / (1 - wc.cuttingLossRate);
    final ms2 = (ms1 + wc.dryingCost) / (1 - avgMoisture);
    final ms3 = ms2 / (1 - wc.marginRate);
    final ms4 = ms3 / (1 - CostCalculator.defaultFinalLossRate);

    final weightKg = recipe.packagingWeight / 1000.0;
    final kgCostPart = ms4 * weightKg;
    final pkgCostPart = recipe.calculatedPrice - kgCostPart;

    return _MixedCalc(
      avgPrice: avgPrice, avgMoisture: avgMoisture,
      ms1: ms1, ms2: ms2, ms3: ms3, ms4: ms4,
      kgCostPart: kgCostPart, pkgCostPart: pkgCostPart,
      ingDetails: ingDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = recipe.isSingleIngredient;
    final color = isSingle ? AppTheme.primary : AppTheme.warning;
    final typeLabel = isSingle ? '단미' : '혼합';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(children: [
                Icon(Icons.receipt_long, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(recipe.name,
                        style: AppText.heading3, overflow: TextOverflow.ellipsis),
                    Text(Fmt.datetime(recipe.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    iconSize: 20,
                    padding: EdgeInsets.zero),
              ]),
            ),
            const Divider(height: 16),

            // ── 스크롤 가능한 본문 ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 기본 정보
                    _buildBasicInfo(color, typeLabel),
                    const SizedBox(height: 16),

                    // 원료 구성 섹션
                    _buildIngredientSection(color),
                    const SizedBox(height: 16),

                    // 원가 계산식 섹션
                    if (isSingle) _buildSingleFormula(color)
                    else _buildMixedFormula(color),
                    const SizedBox(height: 16),

                    // 포장 단가 분해
                    _buildPackagingBreakdown(color),
                    const SizedBox(height: 16),

                    // 최종 단가 요약
                    _buildFinalSummary(color),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 기본 정보 ──
  Widget _buildBasicInfo(Color color, String typeLabel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          _InfoChip(typeLabel, color),
          const SizedBox(width: 8),
          _InfoChip(_catLabel(recipe.weightCategory), AppTheme.textSecondary),
          const SizedBox(width: 8),
          _InfoChip(_pkgLabel(recipe.packagingType), AppTheme.textSecondary),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _InfoItem('포장중량', '${recipe.packagingWeight.toStringAsFixed(0)}g'),
          const SizedBox(width: 16),
          if (recipe.weightCategory == 'bulk')
            _InfoItem('벌크MOQ', '${recipe.bulkMoqKg.toStringAsFixed(0)}kg'),
          if (recipe.workerName.isNotEmpty)
            _InfoItem('작업자', recipe.workerName),
        ]),
      ]),
    );
  }

  // ── 원료 구성 ──
  Widget _buildIngredientSection(Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle('📦 원료 구성', color),
      const SizedBox(height: 6),
      ...recipe.items.map((item) {
        final ing = ingredients.where((i) => i.id == item.ingredientId).firstOrNull;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${item.ratio.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.ingredientName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (ing != null)
                Text(
                  '단가 ${Fmt.won(ing.unitPrice)}/kg · 수분 ${(ing.moisture*100).toStringAsFixed(1)}% · 수율 ${((1-ing.moisture)*100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                )
              else
                const Text('원물 정보 없음 (삭제된 원물)',
                    style: TextStyle(fontSize: 11, color: AppTheme.danger)),
            ])),
            if (ing != null)
              Text(Fmt.won(ing.unitPrice * (item.ratio / 100)),
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ]),
        );
      }),
    ]);
  }

  // ── 단미 계산식 ──
  Widget _buildSingleFormula(Color color) {
    final c = _calcSingle();
    if (c.ing == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
        ),
        child: const Text('원물 정보가 삭제되어 계산식을 표시할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: AppTheme.danger)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle('🔢 단미 원가 계산식', color),
      const SizedBox(height: 6),

      // 입력값
      _inputBox([
        '원물단가: ${Fmt.won(c.ing!.unitPrice)}/kg',
        '수분율: ${(c.ing!.moisture*100).toStringAsFixed(1)}%  →  수율: ${((1-c.ing!.moisture)*100).toStringAsFixed(1)}%',
        '건조비: ${Fmt.won(wc.dryingCost)}/kg  ·  절단비: ${Fmt.won(wc.cuttingCost)}/kg  ·  절단로스: ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%',
        '마진율: ${(wc.marginRate*100).toStringAsFixed(1)}%  ·  최종로스: 3% (고정)',
      ]),
      const SizedBox(height: 8),

      _StepBox(step: 'STEP 1', label: '절단 후 원물가',
        formula: '(${Fmt.won(c.ing!.unitPrice)} + ${Fmt.won(wc.cuttingCost)}절단비) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)',
        result: Fmt.won(c.s1) + '/kg', color: color),
      _StepBox(step: 'STEP 2', label: '건조 후 순수 원가',
        formula: '(${Fmt.won(c.s1)} + ${Fmt.won(wc.dryingCost)}건조비) ÷ (1 - ${(c.ing!.moisture*100).toStringAsFixed(1)}%수분)',
        result: Fmt.won(c.s2) + '/kg', color: color, highlight: true),
      _StepBox(step: 'STEP 3', label: '마진 적용',
        formula: '${Fmt.won(c.s2)} ÷ (1 - ${(wc.marginRate*100).toStringAsFixed(1)}%)',
        result: Fmt.won(c.s3) + '/kg', color: color),
      _StepBox(step: 'STEP 4', label: '최종로스 3% 적용',
        formula: '${Fmt.won(c.s3)} ÷ (1 - 3%)',
        result: Fmt.won(c.s4) + '/kg', color: color, highlight: true),
    ]);
  }

  // ── 혼합 계산식 ──
  Widget _buildMixedFormula(Color color) {
    final c = _calcMixed();
    if (c.ingDetails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('원물 정보가 없어 계산식을 표시할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: AppTheme.danger)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle('🔢 혼합 원가 계산식', color),
      const SizedBox(height: 6),

      // 가중평균 박스
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('① 원물별 가중평균 계산',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          ...c.ingDetails.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Container(width: 3, height: 3, decoration: const BoxDecoration(
                color: AppTheme.textSecondary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '${d.name} ${d.ratio.toStringAsFixed(0)}%: ${Fmt.won(d.unitPrice)} × ${d.ratio.toStringAsFixed(0)}% = ${Fmt.won(d.weightedCost)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontFamily: 'monospace'),
              )),
            ]),
          )),
          const Divider(height: 10),
          Row(children: [
            Expanded(child: Text('가중평균 원물가: ${Fmt.won(c.avgPrice)}/kg',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
            Text('평균수분: ${(c.avgMoisture*100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),

      // 입력값 요약
      _inputBox([
        '가중평균 원물가: ${Fmt.won(c.avgPrice)}/kg  ·  평균수분: ${(c.avgMoisture*100).toStringAsFixed(1)}%',
        '배합비: ${Fmt.won(wc.mixingCost)}/kg  ·  건조비: ${Fmt.won(wc.dryingCost)}/kg  ·  절단비: ${Fmt.won(wc.cuttingCost)}/kg',
        '절단로스: ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%  ·  마진율: ${(wc.marginRate*100).toStringAsFixed(1)}%  ·  최종로스: 3%',
      ]),
      const SizedBox(height: 8),

      _StepBox(step: 'STEP 1', label: '절단 후 원물가',
        formula: '(${Fmt.won(c.avgPrice)} + ${Fmt.won(wc.mixingCost)}배합비 + ${Fmt.won(wc.cuttingCost)}절단비) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)',
        result: Fmt.won(c.ms1) + '/kg', color: color),
      _StepBox(step: 'STEP 2', label: '건조 후 순수 원가',
        formula: '(${Fmt.won(c.ms1)} + ${Fmt.won(wc.dryingCost)}건조비) ÷ (1 - ${(c.avgMoisture*100).toStringAsFixed(1)}%수분)',
        result: Fmt.won(c.ms2) + '/kg', color: color, highlight: true),
      _StepBox(step: 'STEP 3', label: '마진 적용',
        formula: '${Fmt.won(c.ms2)} ÷ (1 - ${(wc.marginRate*100).toStringAsFixed(1)}%)',
        result: Fmt.won(c.ms3) + '/kg', color: color),
      _StepBox(step: 'STEP 4', label: '최종로스 3% 적용',
        formula: '${Fmt.won(c.ms3)} ÷ (1 - 3%)',
        result: Fmt.won(c.ms4) + '/kg', color: color, highlight: true),
    ]);
  }

  // ── 포장 단가 분해 ──
  Widget _buildPackagingBreakdown(Color color) {
    final isSingle = recipe.isSingleIngredient;
    final kgPrice = isSingle ? _calcSingle().s4 : _calcMixed().ms4;
    final weightKg = recipe.packagingWeight / 1000.0;
    final kgCostPart = kgPrice * weightKg;
    final pkgCostPart = recipe.calculatedPrice - kgCostPart;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle('📐 포장당 단가 분해', color),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [
          _BreakdownRow(
            label: 'kg당 단가 × 포장중량',
            detail: '${Fmt.won(kgPrice)}/kg × ${recipe.packagingWeight.toStringAsFixed(0)}g',
            value: Fmt.won(kgCostPart),
            color: color,
          ),
          const Divider(height: 14),
          _BreakdownRow(
            label: '포장비 (용기+포장작업)',
            detail: pkgCostPart > 0
                ? '통값 + 포장작업비 = ${Fmt.won(pkgCostPart)}'
                : '포장비 없음 또는 비닐',
            value: pkgCostPart > 0 ? Fmt.won(pkgCostPart) : '-',
            color: AppTheme.textSecondary,
          ),
          const Divider(height: 14),
          Row(children: [
            const Text('포장당 최종 단가',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(Fmt.won(recipe.calculatedPrice),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ]),
        ]),
      ),
    ]);
  }

  // ── 최종 요약 ──
  Widget _buildFinalSummary(Color color) {
    final isSingle = recipe.isSingleIngredient;
    final pureCost = isSingle ? _calcSingle().s2 : _calcMixed().ms2;
    final finalKgPrice = isSingle ? _calcSingle().s4 : _calcMixed().ms4;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.summarize_outlined, color: color, size: 14),
          const SizedBox(width: 6),
          Text('최종 단가 요약',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SummaryItem(
            label: '순수 원가',
            value: '${Fmt.won(pureCost)}/kg',
            sub: '마진·로스 제외',
            color: AppTheme.textSecondary,
          )),
          Container(width: 1, height: 40, color: color.withValues(alpha: 0.2)),
          Expanded(child: _SummaryItem(
            label: '최종 kg단가',
            value: '${Fmt.won(finalKgPrice)}/kg',
            sub: '마진+로스 포함',
            color: color,
          )),
          Container(width: 1, height: 40, color: color.withValues(alpha: 0.2)),
          Expanded(child: _SummaryItem(
            label: '포장당 단가',
            value: Fmt.won(recipe.calculatedPrice),
            sub: '${recipe.packagingWeight.toStringAsFixed(0)}g 기준',
            color: color,
          )),
        ]),
        const SizedBox(height: 8),
        const Text(
          '※ 예상 단가이며 샘플 가공 후 확정됩니다.',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ]),
    );
  }

  Widget _inputBox(List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(l, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        )).toList(),
      ),
    );
  }
}

// ── 계산 결과 데이터 클래스 ──
class _SingleCalc {
  final Ingredient? ing;
  final double s1, s2, s3, s4;
  final double kgCostPart, pkgCostPart;
  _SingleCalc({required this.ing, required this.s1, required this.s2,
    required this.s3, required this.s4,
    required this.kgCostPart, required this.pkgCostPart});
  factory _SingleCalc.empty() =>
      _SingleCalc(ing: null, s1: 0, s2: 0, s3: 0, s4: 0, kgCostPart: 0, pkgCostPart: 0);
}

class _IngLine {
  final String name;
  final double ratio, unitPrice, moisture, weightedCost;
  _IngLine({required this.name, required this.ratio, required this.unitPrice,
    required this.moisture, required this.weightedCost});
}

class _MixedCalc {
  final double avgPrice, avgMoisture;
  final double ms1, ms2, ms3, ms4;
  final double kgCostPart, pkgCostPart;
  final List<_IngLine> ingDetails;
  _MixedCalc({required this.avgPrice, required this.avgMoisture,
    required this.ms1, required this.ms2, required this.ms3, required this.ms4,
    required this.kgCostPart, required this.pkgCostPart,
    required this.ingDetails});
  factory _MixedCalc.empty() =>
      _MixedCalc(avgPrice: 0, avgMoisture: 0, ms1: 0, ms2: 0, ms3: 0, ms4: 0,
          kgCostPart: 0, pkgCostPart: 0, ingDetails: []);
}

// ── 공통 위젯 ──
class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
  ]);
}

class _InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: '$label: ',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    TextSpan(text: value,
        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
  ]));
}

class _StepBox extends StatelessWidget {
  final String step, label, formula, result;
  final Color color;
  final bool highlight;
  const _StepBox({
    required this.step, required this.label,
    required this.formula, required this.result,
    required this.color, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.06) : AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: highlight ? color.withValues(alpha: 0.35) : AppTheme.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: highlight ? color : AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(step,
                style: const TextStyle(
                    fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: highlight ? color : AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(formula,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textPrimary, fontFamily: 'monospace')),
        ])),
        const SizedBox(width: 8),
        Text(result,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? color : AppTheme.textPrimary)),
      ]),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label, detail, value;
  final Color color;
  const _BreakdownRow({
    required this.label, required this.detail,
    required this.value, required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      Text(detail, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ])),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _SummaryItem extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _SummaryItem({
    required this.label, required this.value,
    required this.sub, required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    const SizedBox(height: 4),
    Text(value,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        textAlign: TextAlign.center),
    Text(sub, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
  ]);
}
