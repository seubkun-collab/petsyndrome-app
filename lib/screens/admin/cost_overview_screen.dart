import 'package:flutter/material.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../services/cost_calculator.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

RecipeItem _makeRecipeItem(Ingredient ing) =>
    RecipeItem(ingredientId: ing.id, ingredientName: ing.name, ratio: 100);

class CostOverviewScreen extends StatefulWidget {
  const CostOverviewScreen({super.key});
  @override
  State<CostOverviewScreen> createState() => _CostOverviewScreenState();
}

class _CostOverviewScreenState extends State<CostOverviewScreen> {
  String _filter = 'all';
  String _search = '';

  List<Ingredient> get _items {
    var list = DataService.getIngredients();
    if (_filter == 'raw') list = list.where((i) => i.type == 'raw').toList();
    if (_filter == 'sub') list = list.where((i) => i.type == 'sub').toList();
    if (_search.isNotEmpty) list = list.where((i) => i.name.contains(_search)).toList();
    return list;
  }

  // 계산식 상세 팝업
  void _showFormulaDetail(BuildContext ctx, Ingredient ing, bool isMixed) {
    final wc = DataService.getWorkCost();
    showDialog(context: ctx, builder: (_) => _FormulaDialog(ing: ing, wc: wc, isMixed: isMixed));
  }

  void _showHistory(Ingredient ing) {
    showDialog(context: context, builder: (_) => _CostHistoryDialog(ingredient: ing));
  }

  // 단가 수정 팝업
  void _openEdit(Ingredient ing) {
    showDialog(
      context: context,
      builder: (_) => _QuickEditDialog(
        ingredient: ing,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wc = DataService.getWorkCost();
    final items = _items;
    final isWide = MediaQuery.of(context).size.width > 800;

    final allIngs = DataService.getIngredients();
    DateTime? lastUpdate;
    if (allIngs.isNotEmpty) {
      lastUpdate = allIngs.map((i) => i.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('원가 조회')),
      body: Column(
        children: [
          // 작업비 요약
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('현재 적용 작업비', style: AppText.label),
                const Spacer(),
                if (lastUpdate != null)
                  GestureDetector(
                    onTap: () => _showAllHistory(context),
                    child: Row(children: [
                      const Icon(Icons.update, size: 12, color: AppTheme.info),
                      const SizedBox(width: 4),
                      Text('원물 마지막 업데이트: ${Fmt.datetime(lastUpdate)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.info, decoration: TextDecoration.underline)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _IChip('건조비', '${Fmt.won(wc.dryingCost)}/kg'),
                _IChip('배합비', '${Fmt.won(wc.mixingCost)}/kg'),
                _IChip('절단비', '${Fmt.won(wc.cuttingCost)}/kg'),
                _IChip('절단로스', Fmt.pct(wc.cuttingLossRate)),
                _IChip('마진율', Fmt.pct(wc.marginRate)),
                _IChip('최종로스', '3% (고정)'),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  '💡 단미/배합 원가 숫자를 클릭하면 실제 계산식을 확인할 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: AppTheme.primary),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // 검색/필터
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Expanded(child: TextField(
                decoration: const InputDecoration(hintText: '원물명 검색...', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              )),
              const SizedBox(width: 10),
              _FBtn('전체', 'all', _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 6),
              _FBtn('원재료', 'raw', _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 6),
              _FBtn('부재료', 'sub', _filter, (v) => setState(() => _filter = v)),
            ]),
          ),
          const Divider(height: 1),

          if (isWide) Container(
            color: const Color(0xFFF3F4F6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(children: [
              SizedBox(width: 56, child: Text('구분', style: AppText.label)),
              Expanded(flex: 3, child: Text('원물명', style: AppText.label)),
              Expanded(flex: 2, child: Text('원물단가', style: AppText.label)),
              Expanded(flex: 2, child: Text('수율', style: AppText.label)),
              Expanded(flex: 2, child: Text('300cc기준(g)', style: AppText.label)),
              Expanded(flex: 3, child: Text('단미원가/kg ⓘ', style: AppText.label)),
              Expanded(flex: 3, child: Text('배합원가/kg ⓘ', style: AppText.label)),
              Expanded(flex: 3, child: Text('수정일(이력)', style: AppText.label)),
              SizedBox(width: 40),
            ]),
          ),
          const Divider(height: 1),

          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('검색 결과가 없습니다.', style: AppText.bodySmall))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final ing = items[i];
                      // 마진·최종로스 제외한 순수 원가 (목록 표시용)
                      final singlePrice = CostCalculator.calcSingleRawCostNoMargin(
                          unitPrice: ing.unitPrice, moisture: ing.moisture, wc: wc);
                      final mixedPrice = CostCalculator.calcMixedRawCostNoMargin(
                          items: [_makeRecipeItem(ing)], ingredients: [ing], wc: wc);
                      final hasHist = ing.history.isNotEmpty;

                      if (isWide) {
                        return Container(
                          color: AppTheme.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(children: [
                            SizedBox(width: 56, child: _TypeBadge(type: ing.type)),
                            Expanded(flex: 3, child: Text(ing.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            Expanded(flex: 2, child: Text(Fmt.won(ing.unitPrice), style: const TextStyle(fontSize: 13))),
                            Expanded(flex: 2, child: Text('${((1-ing.moisture)*100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13))),
                            Expanded(flex: 2, child: Text(
                              ing.ref300ccWeightG > 0 ? '${ing.ref300ccWeightG.toStringAsFixed(0)}g' : '-',
                              style: TextStyle(fontSize: 13, color: ing.ref300ccWeightG > 0 ? AppTheme.textPrimary : AppTheme.textSecondary),
                            )),
                            // 단미원가 - 클릭 가능
                            Expanded(flex: 3, child: GestureDetector(
                              onTap: () => _showFormulaDetail(ctx, ing, false),
                              child: Row(children: [
                                Text('${Fmt.won(singlePrice)}/kg',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                                const SizedBox(width: 3),
                                const Icon(Icons.calculate_outlined, size: 12, color: AppTheme.primary),
                              ]),
                            )),
                            // 배합원가 - 클릭 가능
                            Expanded(flex: 3, child: GestureDetector(
                              onTap: () => _showFormulaDetail(ctx, ing, true),
                              child: Row(children: [
                                Text('${Fmt.won(mixedPrice)}/kg',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                                const SizedBox(width: 3),
                                const Icon(Icons.calculate_outlined, size: 12, color: AppTheme.warning),
                              ]),
                            )),
                            Expanded(flex: 3, child: GestureDetector(
                              onTap: hasHist ? () => _showHistory(ing) : null,
                              child: Row(children: [
                                Text(Fmt.date(ing.updatedAt),
                                    style: TextStyle(fontSize: 11,
                                        color: hasHist ? AppTheme.info : AppTheme.textSecondary,
                                        decoration: hasHist ? TextDecoration.underline : null)),
                                if (hasHist) ...[
                                  const SizedBox(width: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
                                    child: Text('${ing.history.length}', style: const TextStyle(fontSize: 9, color: AppTheme.info, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ]),
                            )),
                            // 수정 버튼
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                color: AppTheme.textSecondary,
                                tooltip: '단가 수정',
                                onPressed: () => _openEdit(ing),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ]),
                        );
                      }

                      // 모바일 카드
                      return Container(
                        color: AppTheme.surface,
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _TypeBadge(type: ing.type),
                            const SizedBox(width: 8),
                            Text(ing.name, style: AppText.heading3),
                            const Spacer(),
                            GestureDetector(
                              onTap: hasHist ? () => _showHistory(ing) : null,
                              child: Text(Fmt.date(ing.updatedAt),
                                  style: TextStyle(fontSize: 11,
                                      color: hasHist ? AppTheme.info : AppTheme.textSecondary,
                                      decoration: hasHist ? TextDecoration.underline : null)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 12, runSpacing: 4, children: [
                            _IChip('원물단가', '${Fmt.won(ing.unitPrice)}/kg'),
                            _IChip('수율', '${((1-ing.moisture)*100).toStringAsFixed(1)}%'),
                            if (ing.ref300ccWeightG > 0) _IChip('300cc기준', '${ing.ref300ccWeightG.toStringAsFixed(0)}g'),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            GestureDetector(
                              onTap: () => _showFormulaDetail(ctx, ing, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.calculate_outlined, size: 13, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  Text('단미 ${Fmt.won(singlePrice)}/kg',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFormulaDetail(ctx, ing, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.calculate_outlined, size: 13, color: AppTheme.warning),
                                  const SizedBox(width: 4),
                                  Text('배합 ${Fmt.won(mixedPrice)}/kg',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                            const Spacer(),
                            // 수정 버튼 (모바일)
                            TextButton.icon(
                              onPressed: () => _openEdit(ing),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('수정', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAllHistory(BuildContext context) {
    final allIngs = DataService.getIngredients().where((i) => i.history.isNotEmpty).toList();
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('전체 원물 단가 변동 이력', style: AppText.heading3)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
            ]),
            const Divider(),
            Expanded(child: allIngs.isEmpty
              ? const Center(child: Text('변동 이력이 없습니다.', style: AppText.bodySmall))
              : ListView(children: allIngs.map((ing) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(ing.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary))),
                    ...ing.history.reversed.map((h) => Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.arrow_right, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(h.note, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                        Text(Fmt.date(h.changedAt), style: AppText.bodySmall),
                      ]),
                    )),
                    const Divider(height: 8),
                  ]);
                }).toList()),
            ),
          ]),
        ),
      ),
    ));
  }
}

// ══════════════════════════════════════════════════
// 계산식 상세 다이얼로그
// ══════════════════════════════════════════════════
class _FormulaDialog extends StatelessWidget {
  final Ingredient ing;
  final dynamic wc; // WorkCost
  final bool isMixed;

  const _FormulaDialog({required this.ing, required this.wc, required this.isMixed});

  @override
  Widget build(BuildContext context) {
    const finalLoss = CostCalculator.defaultFinalLossRate; // 3%

    // 단계별 계산
    final mixingStep = isMixed ? wc.mixingCost : 0.0;
    final baseStep1 = (ing.unitPrice + mixingStep + wc.cuttingCost) / (1 - wc.cuttingLossRate);
    // STEP2 = 순수 원가 (마진 없음)
    final pureCost = (baseStep1 + wc.dryingCost) / (1 - ing.moisture);
    // STEP3 = 마진 적용
    final step3 = pureCost / (1 - wc.marginRate);
    // STEP4 = 최종 판매단가 (마진+로스)
    final finalPrice = step3 / (1 - finalLoss);

    final formulaType = isMixed ? '배합' : '단미';
    final color = isMixed ? AppTheme.warning : AppTheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.calculate_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${ing.name} - $formulaType 원가 계산식',
                    style: AppText.heading3, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20, padding: EdgeInsets.zero),
              ]),
              const Divider(),

              // 입력값 요약
              _SectionTitle('📥 입력값'),
              _FormulaRow('원물단가', '${Fmt.won(ing.unitPrice)}/kg'),
              _FormulaRow('수분율', Fmt.pct(ing.moisture)),
              _FormulaRow('건조비', '${Fmt.won(wc.dryingCost)}/kg'),
              if (isMixed) _FormulaRow('배합작업비', '${Fmt.won(wc.mixingCost)}/kg'),
              _FormulaRow('절단비', '${Fmt.won(wc.cuttingCost)}/kg'),
              _FormulaRow('절단로스율', Fmt.pct(wc.cuttingLossRate)),
              _FormulaRow('마진율', Fmt.pct(wc.marginRate)),
              _FormulaRow('최종로스율', '3% (고정)'),
              const Divider(height: 20),

              // ── 순수 원가 구간 ──
              _SectionTitle('🔢 순수 원가 계산 (마진 제외)'),
              _StepBox(
                step: 'STEP 1',
                label: isMixed
                    ? '(원물가+배합비+절단비) ÷ (1 - 절단로스율)'
                    : '(원물가+절단비) ÷ (1 - 절단로스율)',
                calc: isMixed
                    ? '(${Fmt.won(ing.unitPrice)} + ${Fmt.won(wc.mixingCost)} + ${Fmt.won(wc.cuttingCost)}) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)'
                    : '(${Fmt.won(ing.unitPrice)} + ${Fmt.won(wc.cuttingCost)}) ÷ (1 - ${(wc.cuttingLossRate*100).toStringAsFixed(1)}%)',
                result: '= ${Fmt.won(baseStep1)}',
              ),
              _StepBox(
                step: 'STEP 2',
                label: '(STEP1 + 건조비) ÷ (1 - 수분율)',
                calc: '(${Fmt.won(baseStep1)} + ${Fmt.won(wc.dryingCost)}) ÷ (1 - ${(ing.moisture*100).toStringAsFixed(1)}%)',
                result: '= ${Fmt.won(pureCost)}',
                highlight: true,
              ),

              // 순수 원가 요약 박스
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.arrow_right, color: color, size: 16),
                  const SizedBox(width: 4),
                  Text('$formulaType 순수 원가 ', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  Text(Fmt.won(pureCost),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  Text('/kg', style: TextStyle(fontSize: 11, color: color)),
                  const SizedBox(width: 6),
                  const Text('← 목록 표시 기준', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ]),
              ),

              const Divider(height: 16),

              // ── 최종 판매단가 구간 ──
              _SectionTitle('💰 최종 판매단가 (마진+로스 포함)'),
              _StepBox(
                step: 'STEP 3',
                label: '순수원가 ÷ (1 - 마진율)',
                calc: '${Fmt.won(pureCost)} ÷ (1 - ${(wc.marginRate*100).toStringAsFixed(1)}%)',
                result: '= ${Fmt.won(step3)}',
              ),
              _StepBox(
                step: 'STEP 4',
                label: 'STEP3 ÷ (1 - 최종로스율 3%)',
                calc: '${Fmt.won(step3)} ÷ (1 - 3%)',
                result: '= ${Fmt.won(finalPrice)}',
                highlight: true,
              ),
              const SizedBox(height: 8),

              // 최종 판매단가 요약 박스
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('최종 판매단가/kg (마진+로스 포함)',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Fmt.won(finalPrice),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.orange)),
                  const SizedBox(height: 4),
                  Text(
                    isMixed
                        ? '= 순수원가/(1-마진)/(1-3%로스)'
                        : '= 순수원가/(1-마진)/(1-3%로스)',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
  );
}

class _FormulaRow extends StatelessWidget {
  final String label, value;
  const _FormulaRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: AppText.bodySmall)),
      Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _StepBox extends StatelessWidget {
  final String step, label, calc, result;
  final bool highlight;
  const _StepBox({required this.step, required this.label, required this.calc, required this.result, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: highlight ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: highlight ? AppTheme.primary : AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(step, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: highlight ? AppTheme.primary : AppTheme.textSecondary))),
        ]),
        const SizedBox(height: 4),
        Text(calc, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontFamily: 'monospace')),
        Text(result, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? AppTheme.primary : AppTheme.textPrimary)),
      ]),
    );
  }
}

class _CostHistoryDialog extends StatelessWidget {
  final Ingredient ingredient;
  const _CostHistoryDialog({required this.ingredient});
  @override
  Widget build(BuildContext context) {
    final hist = ingredient.history.reversed.toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('${ingredient.name} 단가 변동', style: AppText.heading3)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
            ]),
            Text('현재: ${Fmt.won(ingredient.unitPrice)}/kg | 수분 ${Fmt.pct(ingredient.moisture)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
            const Divider(),
            hist.isEmpty
                ? const Expanded(child: Center(child: Text('변동 이력이 없습니다.', style: AppText.bodySmall)))
                : Expanded(child: ListView.separated(
                    itemCount: hist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final h = hist[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Container(width: 26, height: 26,
                              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(13)),
                              child: Center(child: Text('${hist.length - i}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.note, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                            Text(Fmt.datetime(h.changedAt), style: AppText.bodySmall),
                          ])),
                        ]),
                      );
                    },
                  )),
          ]),
        ),
      ),
    );
  }
}

class _IChip extends StatelessWidget {
  final String label, value;
  const _IChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: '$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    TextSpan(text: value, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
  ]));
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final isRaw = type == 'raw';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: (isRaw ? AppTheme.primary : AppTheme.warning).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(isRaw ? '원재료' : '부재료',
          style: TextStyle(fontSize: 10, color: isRaw ? AppTheme.primary : AppTheme.warning, fontWeight: FontWeight.w600)),
    );
  }
}

class _FBtn extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FBtn(this.label, this.value, this.current, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(onTap: () => onTap(value), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? AppTheme.primary : AppTheme.border)),
      child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
    ));
  }
}

// ══════════════════════════════════════════════════
// 단가 빠른 수정 다이얼로그
// ══════════════════════════════════════════════════
class _QuickEditDialog extends StatefulWidget {
  final Ingredient ingredient;
  final VoidCallback onSaved;
  const _QuickEditDialog({required this.ingredient, required this.onSaved});
  @override
  State<_QuickEditDialog> createState() => _QuickEditDialogState();
}

class _QuickEditDialogState extends State<_QuickEditDialog> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _moistureCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.ingredient.unitPrice.toStringAsFixed(0));
    _moistureCtrl = TextEditingController(
        text: (widget.ingredient.moisture * 100).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _moistureCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    final moisture = double.tryParse(_moistureCtrl.text.trim());
    if (price == null || moisture == null) return;
    setState(() => _saving = true);
    final ing = widget.ingredient;
    final updated = Ingredient(
      id: ing.id,
      name: ing.name,
      type: ing.type,
      unitPrice: price,
      moisture: moisture / 100.0,
      crudeProtein: ing.crudeProtein,
      crudeFat: ing.crudeFat,
      crudeAsh: ing.crudeAsh,
      crudeFiber: ing.crudeFiber,
      calcium: ing.calcium,
      phosphorus: ing.phosphorus,
      bulkWeightKg: ing.bulkWeightKg,
      createdAt: ing.createdAt,
    );
    await DataService.saveIngredient(updated);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${widget.ingredient.name} 수정',
                      style: AppText.heading3, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const Divider(height: 20),
              // 원물단가
              const Text('원물단가 (원/kg)', style: AppText.label),
              const SizedBox(height: 6),
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  suffixText: '원/kg',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              // 수분율 (수율 자동 표시)
              const Text('수분율 (%)', style: AppText.label),
              const SizedBox(height: 6),
              TextField(
                controller: _moistureCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? '저장 중...' : '저장'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
