import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';


/// 이카운트 견적서 작성 화면
/// 고객 견적 이력에서 항목을 선택해 이카운트 견적서 양식으로 출력합니다.
class ICountEstimateScreen extends StatefulWidget {
  const ICountEstimateScreen({super.key});
  @override
  State<ICountEstimateScreen> createState() => _ICountEstimateScreenState();
}

class _ICountEstimateScreenState extends State<ICountEstimateScreen> {
  // 선택된 견적 항목들
  final Set<String> _selected = {};
  String _search = '';

  // 견적서 헤더 정보
  final _customerNameCtrl = TextEditingController();
  final _customerContactCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _estimateDate = DateTime.now();
  int _validDays = 30;

  List<Recipe> get _recipes {
    var list = DataService.getRecipes();
    if (_search.isNotEmpty) {
      list = list.where((r) =>
        r.name.contains(_search) ||
        r.workerName.contains(_search) ||
        r.items.any((it) => it.ingredientName.contains(_search))
      ).toList();
    }
    return list;
  }

  List<Recipe> get _selectedRecipes =>
      _recipes.where((r) => _selected.contains(r.id)).toList();

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerContactCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _estimateDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _estimateDate = picked);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _recipes.length) {
        _selected.clear();
      } else {
        _selected.addAll(_recipes.map((r) => r.id));
      }
    });
  }

  String _buildEstimateText() {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('           펫신드룸 견적서');
    buf.writeln('═══════════════════════════════════');
    buf.writeln('견적일: ${_formatDate(_estimateDate)}');
    buf.writeln('유효기간: ${'${_estimateDate.add(Duration(days: _validDays)).year}년 ${_estimateDate.add(Duration(days: _validDays)).month}월 ${_estimateDate.add(Duration(days: _validDays)).day}일'} (${_validDays}일)');
    if (_customerNameCtrl.text.isNotEmpty) {
      buf.writeln('고객명: ${_customerNameCtrl.text.trim()}');
    }
    if (_customerContactCtrl.text.isNotEmpty) {
      buf.writeln('연락처: ${_customerContactCtrl.text.trim()}');
    }
    buf.writeln('───────────────────────────────────');
    buf.writeln('No. | 품목 | 포장 | 수량 | 단가 | 금액');
    buf.writeln('───────────────────────────────────');

    final items = _selectedRecipes;
    double total = 0;
    for (int i = 0; i < items.length; i++) {
      final r = items[i];
      final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
      final packLabel = _packLabel(r);
      final price = r.calculatedPrice;
      final qty = 1;
      total += price * qty;
      buf.writeln('${i + 1}. $ingNames');
      buf.writeln('   $packLabel | ${qty}개 | ${Fmt.won(price)} | ${Fmt.won(price * qty)}');
    }

    buf.writeln('───────────────────────────────────');
    buf.writeln('합계: ${Fmt.won(total)}');
    if (_noteCtrl.text.isNotEmpty) {
      buf.writeln('───────────────────────────────────');
      buf.writeln('비고: ${_noteCtrl.text.trim()}');
    }
    buf.writeln('═══════════════════════════════════');
    buf.writeln('※ 본 견적은 예상 단가입니다. 확정 견적은 별도 문의 바랍니다.');
    buf.writeln('공급자: 펫신드룸');
    return buf.toString();
  }

  String _packLabel(Recipe r) {
    switch (r.packagingType) {
      case 'container':
        return '용기포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
      case 'vinyl':
        return '비닐포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
      case 'bulk':
        return '벌크 ${r.bulkMoqKg.toStringAsFixed(0)}kg';
      default:
        return '포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일';

  void _copyToClipboard() {
    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('견적 항목을 선택해주세요.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: _buildEstimateText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('견적서가 클립보드에 복사되었습니다. 이카운트에 붙여넣기 하세요.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showPreview() {
    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('견적 항목을 선택해주세요.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('견적서 미리보기'),
            const Spacer(),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _buildEstimateText()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('복사 완료'), behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.primary),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              tooltip: '클립보드에 복사',
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                _buildEstimateText(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildEstimateText()));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('복사 완료! 이카운트에 붙여넣기 하세요.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('복사 후 닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    final allSelected = recipes.isNotEmpty && _selected.length == recipes.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 배너
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('이카운트 견적서 작성', style: AppText.heading3),
                        Text('견적 이력에서 항목을 선택해 견적서를 생성하세요', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 이카운트 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: AppTheme.info, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '견적서를 복사한 후 이카운트(ecounterp.com) → 영업 → 견적서 메뉴에서 붙여넣기하여 활용하세요.',
                          style: TextStyle(fontSize: 11, color: AppTheme.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 항목 선택 + 검색
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // 검색 + 전체선택
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: '원료명, 작업자명 검색...',
                                  prefixIcon: Icon(Icons.search, size: 16),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _selectAll,
                              icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 16),
                              label: Text(allSelected ? '선택해제' : '전체선택', style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),

                      // 선택 카운트
                      if (_selected.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppTheme.primary, size: 15),
                              const SizedBox(width: 6),
                              Text('${_selected.length}개 항목 선택됨', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),

                      // 목록
                      Expanded(
                        child: recipes.isEmpty
                            ? const Center(child: Text('견적 이력이 없습니다.', style: TextStyle(color: AppTheme.textSecondary)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: recipes.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 4),
                                itemBuilder: (_, i) {
                                  final r = recipes[i];
                                  final sel = _selected.contains(r.id);
                                  final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
                                  return InkWell(
                                    onTap: () => _toggleSelect(r.id),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: sel ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sel ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sel ? Icons.check_box : Icons.check_box_outline_blank,
                                            size: 18,
                                            color: sel ? AppTheme.primary : AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(ingNames, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${_packLabel(r)} · ${r.workerName.isNotEmpty ? r.workerName : "미기록"} · ${_formatDate(r.createdAt)}',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${Fmt.won(r.calculatedPrice)}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // 오른쪽: 견적서 설정 패널
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppTheme.border)),
                    color: AppTheme.surface,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('견적서 정보', style: AppText.heading3),
                        const SizedBox(height: 16),

                        // 고객명
                        TextField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: '고객명',
                            prefixIcon: Icon(Icons.person_outline, size: 16),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),

                        // 연락처
                        TextField(
                          controller: _customerContactCtrl,
                          decoration: const InputDecoration(
                            labelText: '연락처 (선택)',
                            prefixIcon: Icon(Icons.phone_outlined, size: 16),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),

                        // 견적일
                        GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF9FAFB),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('견적일', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                      Text(_formatDate(_estimateDate), style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 유효기간
                        Row(
                          children: [
                            const Text('유효기간', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const Spacer(),
                            DropdownButton<int>(
                              value: _validDays,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 7, child: Text('7일')),
                                DropdownMenuItem(value: 14, child: Text('14일')),
                                DropdownMenuItem(value: 30, child: Text('30일')),
                                DropdownMenuItem(value: 60, child: Text('60일')),
                                DropdownMenuItem(value: 90, child: Text('90일')),
                              ],
                              onChanged: (v) => setState(() => _validDays = v ?? 30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 비고
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '비고 (선택)',
                            prefixIcon: Icon(Icons.notes_outlined, size: 16),
                            alignLabelWithHint: true,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        // 합계
                        if (_selectedRecipes.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('선택 항목 합계', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  '${Fmt.won(_selectedRecipes.fold(0.0, (sum, r) => sum + r.calculatedPrice))}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                ),
                                Text('${_selectedRecipes.length}개 항목', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        ElevatedButton.icon(
                          onPressed: _selectedRecipes.isEmpty ? null : _showPreview,
                          icon: const Icon(Icons.preview_outlined, size: 16),
                          label: const Text('미리보기'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _selectedRecipes.isEmpty ? null : _copyToClipboard,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('클립보드 복사'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                        ),

                        const SizedBox(height: 16),
                        // 이카운트 바로가기
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이카운트 웹사이트(ecounterp.com)로 이동하세요.\n견적서 복사 후 영업→견적서에 붙여넣기 하세요.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('이카운트 열기', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
