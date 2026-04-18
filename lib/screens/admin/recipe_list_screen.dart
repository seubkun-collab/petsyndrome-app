import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
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

  // 삭제 버그 수정: mounted 체크 + 분리된 confirm 함수
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
            child: const Text('삭제',
                style: TextStyle(color: AppTheme.danger)),
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
    showDialog(
        context: context, builder: (_) => _RecipeDetailDialog(recipe: r));
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                Text(
                    '단미 ${recipes.where((r) => r.isSingleIngredient).length}건',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.primary)),
                const SizedBox(width: 8),
                Text(
                    '혼합 ${recipes.where((r) => !r.isSingleIngredient).length}건',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.warning)),
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
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
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
      case 'over100':
        return '100g이상';
      case 'bulk':
        return '벌크';
      default:
        return '100g이하';
    }
  }

  String _pkgLabel(String pkg) {
    switch (pkg) {
      case 'container':
        return '통포장';
      case 'sample':
        return '샘플';
      default:
        return '비닐';
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
              // 순번
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
              Text(Fmt.won(recipe.calculatedPrice),
                  style: AppText.price),
              const SizedBox(width: 8),
              // 삭제 버튼 (IconButton 대신 GestureDetector로 확실한 클릭 처리)
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.delete_outline,
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
                _Tag('작업자: ${recipe.workerName}',
                    color: AppTheme.info),
            ]),
            const SizedBox(height: 6),
            // 원료 목록
            Text(
              recipe.items
                  .map((it) =>
                      '${it.ingredientName}(${it.ratio.toStringAsFixed(1)}%)')
                  .join(' + '),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time,
                  size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(Fmt.datetime(recipe.createdAt),
                  style: AppText.bodySmall),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── 상세 다이얼로그 ──
class _RecipeDetailDialog extends StatelessWidget {
  final Recipe recipe;
  const _RecipeDetailDialog({required this.recipe});

  String _catLabel(String cat) {
    switch (cat) {
      case 'over100':
        return '100g 이상';
      case 'bulk':
        return '벌크(KG)';
      default:
        return '100g 이하';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(recipe.name,
                        style: AppText.heading3,
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    iconSize: 20),
              ]),
              const Divider(),
              _Row('생성일', Fmt.datetime(recipe.createdAt)),
              if (recipe.workerName.isNotEmpty)
                _Row('작업자', recipe.workerName),
              _Row('유형', recipe.isSingleIngredient ? '단미' : '혼합'),
              _Row('포장 구분', _catLabel(recipe.weightCategory)),
              _Row('포장중량',
                  '${recipe.packagingWeight.toStringAsFixed(0)}g'),
              _Row(
                  '포장방식',
                  recipe.packagingType == 'vinyl'
                      ? '비닐포장'
                      : recipe.packagingType == 'container'
                          ? '통포장'
                          : '샘플포장'),
              if (recipe.weightCategory == 'bulk')
                _Row('벌크 MOQ',
                    '${recipe.bulkMoqKg.toStringAsFixed(0)}kg 단위'),
              const Divider(),
              const Text('원료 구성', style: AppText.label),
              const SizedBox(height: 6),
              ...recipe.items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(it.ingredientName,
                              style: AppText.body)),
                      Text(
                          '${it.ratio.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  )),
              const Divider(),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('예상 단가', style: AppText.heading3),
                    Text(Fmt.won(recipe.calculatedPrice),
                        style: AppText.price),
                  ]),
              const SizedBox(height: 8),
              const Text(
                '※ 예상 단가이며 샘플 가공 후 확정됩니다.',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(label, style: AppText.bodySmall)),
          Expanded(child: Text(value, style: AppText.body)),
        ]),
      );
}
