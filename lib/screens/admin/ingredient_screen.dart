import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../models/ingredient.dart';
import '../../services/data_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

class IngredientScreen extends StatefulWidget {
  const IngredientScreen({super.key});
  @override
  State<IngredientScreen> createState() => _IngredientScreenState();
}

class _IngredientScreenState extends State<IngredientScreen> {
  String _filter = 'all';
  String _search = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await DataService.refreshAll();
    if (mounted) setState(() => _loading = false);
  }

  List<Ingredient> get _filtered {
    var list = DataService.getIngredients(activeOnly: false);
    if (_filter == 'raw') list = list.where((i) => i.type == 'raw').toList();
    if (_filter == 'sub') list = list.where((i) => i.type == 'sub').toList();
    if (_search.isNotEmpty) list = list.where((i) => i.name.contains(_search)).toList();
    return list;
  }

  void _openForm([Ingredient? ing]) {
    showDialog(context: context, builder: (_) => _IngredientFormDialog(ingredient: ing, onSaved: () => setState(() {})));
  }

  Future<void> _delete(Ingredient ing) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('삭제 확인'),
      content: Text('${ing.name}을(를) 삭제하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: AppTheme.danger))),
      ],
    ));
    if (ok == true) { await DataService.deleteIngredient(ing.id); setState(() {}); }
  }

  void _showHistory(Ingredient ing) {
    showDialog(context: context, builder: (_) => _HistoryDialog(ingredient: ing));
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('원물 관리'),
        actions: [
          if (_loading) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: '새로고침', onPressed: _refresh),
          ElevatedButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('원물 추가')),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // 검색 + 필터
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(hintText: '원물명 검색...', prefixIcon: Icon(Icons.search, size: 18), isDense: true), onChanged: (v) => setState(() => _search = v))),
                const SizedBox(width: 10),
                _FChip('전체', 'all', _filter, (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FChip('원재료', 'raw', _filter, (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FChip('부재료', 'sub', _filter, (v) => setState(() => _filter = v)),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Text('총 ${items.length}개', style: AppText.bodySmall),
              const SizedBox(width: 12),
              Text('원재료 ${items.where((i) => i.type == 'raw').length}개', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
              const SizedBox(width: 8),
              Text('부재료 ${items.where((i) => i.type == 'sub').length}개', style: const TextStyle(fontSize: 11, color: AppTheme.warning)),
            ]),
          ),
          const Divider(height: 1),

          if (isWide) _TableHeader(),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('등록된 원물이 없습니다.', style: AppText.bodySmall))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => isWide
                        ? _IngRow(ing: items[i], onEdit: () => _openForm(items[i]), onDelete: () => _delete(items[i]), onHistory: () => _showHistory(items[i]))
                        : _IngCard(ing: items[i], onEdit: () => _openForm(items[i]), onDelete: () => _delete(items[i]), onHistory: () => _showHistory(items[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FChip(this.label, this.value, this.current, this.onTap);
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

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF3F4F6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: const Row(children: [
      SizedBox(width: 56, child: Text('구분', style: AppText.label)),
      Expanded(flex: 3, child: Text('원물명', style: AppText.label)),
      Expanded(flex: 2, child: Text('단가(원/kg)', style: AppText.label)),
      Expanded(flex: 2, child: Text('수분율', style: AppText.label)),
      Expanded(flex: 2, child: Text('조단백', style: AppText.label)),
      Expanded(flex: 2, child: Text('조지방', style: AppText.label)),
      Expanded(flex: 2, child: Text('조회분', style: AppText.label)),
      Expanded(flex: 2, child: Text('조섬유', style: AppText.label)),
      Expanded(flex: 2, child: Text('칼슘', style: AppText.label)),
      Expanded(flex: 2, child: Text('인', style: AppText.label)),
      Expanded(flex: 2, child: Text('벌크', style: AppText.label)),
      Expanded(flex: 3, child: Text('수정일', style: AppText.label)),
      SizedBox(width: 72, child: Text('관리', style: AppText.label)),
    ]),
  );
}

class _IngRow extends StatelessWidget {
  final Ingredient ing;
  final VoidCallback onEdit, onDelete, onHistory;
  const _IngRow({required this.ing, required this.onEdit, required this.onDelete, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final hasHistory = ing.history.isNotEmpty;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(width: 56, child: _TypeBadge(type: ing.type)),
        Expanded(flex: 3, child: Text(ing.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: Text(Fmt.won(ing.unitPrice), style: const TextStyle(fontSize: 13))),
        Expanded(flex: 2, child: Text(Fmt.pct(ing.moisture), style: const TextStyle(fontSize: 13))),
        Expanded(flex: 2, child: Text(ing.crudeProtein != null ? '${Fmt.num(ing.crudeProtein!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(ing.crudeFat != null ? '${Fmt.num(ing.crudeFat!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(ing.crudeAsh != null ? '${Fmt.num(ing.crudeAsh!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(ing.crudeFiber != null ? '${Fmt.num(ing.crudeFiber!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(ing.calcium != null ? '${Fmt.num(ing.calcium!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(ing.phosphorus != null ? '${Fmt.num(ing.phosphorus!)}%' : '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text('${ing.bulkWeightKg.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Expanded(flex: 3, child: GestureDetector(
          onTap: hasHistory ? onHistory : null,
          child: Row(children: [
            Text(Fmt.date(ing.updatedAt), style: TextStyle(fontSize: 11, color: hasHistory ? AppTheme.info : AppTheme.textSecondary, decoration: hasHistory ? TextDecoration.underline : null)),
            if (hasHistory) ...[const SizedBox(width: 3), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)), child: Text('${ing.history.length}', style: const TextStyle(fontSize: 9, color: AppTheme.info, fontWeight: FontWeight.w700)))],
          ]),
        )),
        SizedBox(width: 72, child: Row(children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ])),
      ]),
    );
  }
}

class _IngCard extends StatelessWidget {
  final Ingredient ing;
  final VoidCallback onEdit, onDelete, onHistory;
  const _IngCard({required this.ing, required this.onEdit, required this.onDelete, required this.onHistory});
  @override
  Widget build(BuildContext context) {
    final hasHistory = ing.history.isNotEmpty;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _TypeBadge(type: ing.type),
          const SizedBox(width: 8),
          Expanded(child: Text(ing.name, style: AppText.heading3)),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit, padding: EdgeInsets.zero),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: onDelete, padding: EdgeInsets.zero),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _IC('단가', Fmt.won(ing.unitPrice)),
          _IC('수분율', Fmt.pct(ing.moisture)),
          _IC('벌크', '${ing.bulkWeightKg.toStringAsFixed(0)}kg'),
          if (ing.crudeProtein != null) _IC('조단백', '${Fmt.num(ing.crudeProtein!)}%'),
          if (ing.crudeFat != null) _IC('조지방', '${Fmt.num(ing.crudeFat!)}%'),
          if (ing.calcium != null) _IC('칼슘', '${Fmt.num(ing.calcium!)}%'),
          if (ing.phosphorus != null) _IC('인', '${Fmt.num(ing.phosphorus!)}%'),
        ]),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: hasHistory ? onHistory : null,
          child: Row(children: [
            const Icon(Icons.update, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('수정: ${Fmt.date(ing.updatedAt)}', style: TextStyle(fontSize: 11, color: hasHistory ? AppTheme.info : AppTheme.textSecondary, decoration: hasHistory ? TextDecoration.underline : null)),
            if (hasHistory) Text(' (이력 ${ing.history.length}건)', style: const TextStyle(fontSize: 11, color: AppTheme.info)),
          ]),
        ),
      ]),
    );
  }
}

class _IC extends StatelessWidget {
  final String label, value;
  const _IC(this.label, this.value);
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    TextSpan(text: value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
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
      child: Text(isRaw ? '원재료' : '부재료', style: TextStyle(fontSize: 10, color: isRaw ? AppTheme.primary : AppTheme.warning, fontWeight: FontWeight.w600)),
    );
  }
}

// ── 변동이력 다이얼로그 ──
class _HistoryDialog extends StatelessWidget {
  final Ingredient ingredient;
  const _HistoryDialog({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final hist = ingredient.history.reversed.toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text('${ingredient.name} 변동 이력', style: AppText.heading3)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
              ]),
              Text('현재: ${Fmt.won(ingredient.unitPrice)}/kg | 수분 ${Fmt.pct(ingredient.moisture)}', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              const Divider(),
              hist.isEmpty
                  ? const Expanded(child: Center(child: Text('변동 이력이 없습니다.', style: AppText.bodySmall)))
                  : Expanded(
                      child: ListView.separated(
                        itemCount: hist.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final h = hist[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(14)),
                                child: Center(child: Text('${hist.length - i}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(h.note, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                                Text(Fmt.datetime(h.changedAt), style: AppText.bodySmall),
                              ])),
                            ]),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 원물 입력 다이얼로그 ──
class _IngredientFormDialog extends StatefulWidget {
  final Ingredient? ingredient;
  final VoidCallback onSaved;
  const _IngredientFormDialog({this.ingredient, required this.onSaved});
  @override
  State<_IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends State<_IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _ashCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _calciumCtrl = TextEditingController();
  final _phosphorusCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  final _ref300Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.ingredient;
    _type = i?.type ?? 'raw';
    if (i != null) {
      _nameCtrl.text = i.name;
      _priceCtrl.text = i.unitPrice.toStringAsFixed(0);
      _moistureCtrl.text = (i.moisture * 100).toStringAsFixed(1);
      _proteinCtrl.text = i.crudeProtein?.toStringAsFixed(1) ?? '';
      _fatCtrl.text = i.crudeFat?.toStringAsFixed(1) ?? '';
      _ashCtrl.text = i.crudeAsh?.toStringAsFixed(1) ?? '';
      _fiberCtrl.text = i.crudeFiber?.toStringAsFixed(1) ?? '';
      _calciumCtrl.text = i.calcium?.toStringAsFixed(2) ?? '';
      _phosphorusCtrl.text = i.phosphorus?.toStringAsFixed(2) ?? '';
      _bulkCtrl.text = i.bulkWeightKg.toStringAsFixed(0);
      _ref300Ctrl.text = i.ref300ccWeightG > 0 ? i.ref300ccWeightG.toStringAsFixed(0) : '';
    } else {
      _bulkCtrl.text = '10';
      _ref300Ctrl.text = '';
    }
  }

  double? _opt(String v) => v.trim().isEmpty ? null : double.tryParse(v.trim());

  // 잘 알려진 원물 기본 영양성분 데이터
  static const Map<String, Map<String, double>> _knownNutrition = {
    '닭가슴살': {'moisture': 75, 'protein': 23.0, 'fat': 1.2, 'ash': 1.1, 'fiber': 0.0, 'calcium': 0.01, 'phosphorus': 0.2},
    '연어': {'moisture': 70, 'protein': 20.0, 'fat': 13.0, 'ash': 1.3, 'fiber': 0.0, 'calcium': 0.02, 'phosphorus': 0.25},
    '소고기': {'moisture': 70, 'protein': 21.0, 'fat': 8.0, 'ash': 1.0, 'fiber': 0.0, 'calcium': 0.01, 'phosphorus': 0.2},
    '오리고기': {'moisture': 72, 'protein': 19.0, 'fat': 6.0, 'ash': 1.1, 'fiber': 0.0, 'calcium': 0.01, 'phosphorus': 0.18},
    '명태': {'moisture': 80, 'protein': 17.0, 'fat': 0.5, 'ash': 1.2, 'fiber': 0.0, 'calcium': 0.05, 'phosphorus': 0.2},
    '북어': {'moisture': 15, 'protein': 80.0, 'fat': 1.0, 'ash': 5.0, 'fiber': 0.0, 'calcium': 0.15, 'phosphorus': 0.8},
    '열빙어': {'moisture': 78, 'protein': 15.0, 'fat': 3.0, 'ash': 2.0, 'fiber': 0.0, 'calcium': 0.3, 'phosphorus': 0.25},
    '고구마': {'moisture': 68, 'protein': 1.6, 'fat': 0.1, 'ash': 0.9, 'fiber': 3.0, 'calcium': 0.03, 'phosphorus': 0.05},
    '단호박': {'moisture': 91, 'protein': 1.0, 'fat': 0.1, 'ash': 0.6, 'fiber': 2.7, 'calcium': 0.02, 'phosphorus': 0.04},
    '브로콜리': {'moisture': 90, 'protein': 2.8, 'fat': 0.4, 'ash': 0.9, 'fiber': 2.6, 'calcium': 0.05, 'phosphorus': 0.07},
    '치즈': {'moisture': 40, 'protein': 25.0, 'fat': 30.0, 'ash': 4.0, 'fiber': 0.0, 'calcium': 0.7, 'phosphorus': 0.5},
    '산양유': {'moisture': 87, 'protein': 3.5, 'fat': 4.0, 'ash': 0.8, 'fiber': 0.0, 'calcium': 0.13, 'phosphorus': 0.1},
    '돼지고기': {'moisture': 68, 'protein': 20.0, 'fat': 10.0, 'ash': 1.0, 'fiber': 0.0, 'calcium': 0.01, 'phosphorus': 0.2},
    '참치': {'moisture': 70, 'protein': 26.0, 'fat': 3.0, 'ash': 1.5, 'fiber': 0.0, 'calcium': 0.03, 'phosphorus': 0.3},
    '대구': {'moisture': 80, 'protein': 18.0, 'fat': 0.3, 'ash': 1.3, 'fiber': 0.0, 'calcium': 0.03, 'phosphorus': 0.22},
    '당근': {'moisture': 88, 'protein': 0.9, 'fat': 0.2, 'ash': 1.0, 'fiber': 2.8, 'calcium': 0.03, 'phosphorus': 0.04},
    '시금치': {'moisture': 91, 'protein': 2.5, 'fat': 0.4, 'ash': 1.8, 'fiber': 2.2, 'calcium': 0.1, 'phosphorus': 0.05},
    '블루베리': {'moisture': 84, 'protein': 0.7, 'fat': 0.3, 'ash': 0.2, 'fiber': 2.4, 'calcium': 0.01, 'phosphorus': 0.01},
    '귀리': {'moisture': 8, 'protein': 13.0, 'fat': 6.5, 'ash': 1.9, 'fiber': 10.0, 'calcium': 0.05, 'phosphorus': 0.4},
    '계란': {'moisture': 73, 'protein': 12.5, 'fat': 10.0, 'ash': 1.0, 'fiber': 0.0, 'calcium': 0.05, 'phosphorus': 0.18},
  };

  void _autoFillNutrition() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 원물명을 입력해주세요.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // 정확히 매치 또는 부분 매치
    Map<String, double>? data;
    if (_knownNutrition.containsKey(name)) {
      data = _knownNutrition[name];
    } else {
      // 부분 매치 시도
      for (final key in _knownNutrition.keys) {
        if (name.contains(key) || key.contains(name)) {
          data = _knownNutrition[key];
          break;
        }
      }
    }

    if (data != null) {
      setState(() {
        if (_moistureCtrl.text.isEmpty) _moistureCtrl.text = data!['moisture']!.toStringAsFixed(1);
        if (_proteinCtrl.text.isEmpty) _proteinCtrl.text = data!['protein']!.toStringAsFixed(1);
        if (_fatCtrl.text.isEmpty) _fatCtrl.text = data!['fat']!.toStringAsFixed(1);
        if (_ashCtrl.text.isEmpty) _ashCtrl.text = data!['ash']!.toStringAsFixed(1);
        if (_fiberCtrl.text.isEmpty) _fiberCtrl.text = data!['fiber']!.toStringAsFixed(1);
        if (_calciumCtrl.text.isEmpty) _calciumCtrl.text = data!['calcium']!.toStringAsFixed(2);
        if (_phosphorusCtrl.text.isEmpty) _phosphorusCtrl.text = data!['phosphorus']!.toStringAsFixed(2);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name 영양성분 데이터가 자동 입력되었습니다. 실제 값과 다를 수 있으니 확인 후 수정해주세요.'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)),
      );
    } else {
      // 데이터 없으면 GenSpark 검색 안내
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('영양성분 검색'),
          content: Text('"$name"의 영양성분 데이터가 없습니다.\n\nGenSpark AI로 검색하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final query = Uri.encodeComponent('$name 동결건조 영양성분 수분율 조단백 조지방 조회분 조섬유 칼슘 인');
                final url = 'https://www.genspark.ai/search?q=$query';
                if (kIsWeb) html.window.open(url, '_blank');
              },
              child: const Text('GenSpark 검색'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ing = Ingredient(
      id: widget.ingredient?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      unitPrice: double.parse(_priceCtrl.text.trim()),
      moisture: double.parse(_moistureCtrl.text.trim()) / 100.0,
      crudeProtein: _opt(_proteinCtrl.text),
      crudeFat: _opt(_fatCtrl.text),
      crudeAsh: _opt(_ashCtrl.text),
      crudeFiber: _opt(_fiberCtrl.text),
      calcium: _opt(_calciumCtrl.text),
      phosphorus: _opt(_phosphorusCtrl.text),
      bulkWeightKg: double.tryParse(_bulkCtrl.text.trim()) ?? 10.0,
      ref300ccWeightG: double.tryParse(_ref300Ctrl.text.trim()) ?? 0.0,
      createdAt: widget.ingredient?.createdAt,
    );
    await DataService.saveIngredient(ing);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController ctrl, {bool req = false, String? suffix, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: hint, suffixText: suffix, isDense: true),
        validator: req
            ? (v) => (v == null || v.trim().isEmpty) ? '필수 입력' : (double.tryParse(v.trim()) == null ? '숫자만 입력' : null)
            : (v) => (v != null && v.isNotEmpty && double.tryParse(v.trim()) == null) ? '숫자만 입력' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(widget.ingredient == null ? '원물 추가' : '원물 수정', style: AppText.heading3),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
              ]),
              const Divider(),
              Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                const Text('구분', style: AppText.label),
                const SizedBox(height: 6),
                Row(children: [
                  _TBtn(label: '원재료', value: 'raw', current: _type, onTap: (v) => setState(() => _type = v)),
                  const SizedBox(width: 8),
                  _TBtn(label: '부재료', value: 'sub', current: _type, onTap: (v) => setState(() => _type = v)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: '원물명 *', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '원물명을 입력해주세요' : null,
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                const Text('기본 정보', style: AppText.label),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field('단가 *', _priceCtrl, req: true, suffix: '원/kg')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('수분율 *', _moistureCtrl, req: true, suffix: '%', hint: '예: 75.0')),
                ]),
                Row(children: [
                  Expanded(child: _field('벌크 포장 중량', _bulkCtrl, suffix: 'kg', hint: '기본 10')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('300cc 기준 중량', _ref300Ctrl, suffix: 'g', hint: '미설정시 빈칸')),
                ]),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('영양 성분 (선택)', style: AppText.label),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _autoFillNutrition,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('AI 자동입력', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        foregroundColor: AppTheme.info,
                        side: const BorderSide(color: AppTheme.info),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('빈 항목만 자동 입력됩니다. 입력된 값은 유지됩니다.', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field('조단백', _proteinCtrl, suffix: '%')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('조지방', _fatCtrl, suffix: '%')),
                ]),
                Row(children: [
                  Expanded(child: _field('조회분', _ashCtrl, suffix: '%')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('조섬유', _fiberCtrl, suffix: '%')),
                ]),
                Row(children: [
                  Expanded(child: _field('칼슘', _calciumCtrl, suffix: '%')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('인', _phosphorusCtrl, suffix: '%')),
                ]),
              ]))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _save, child: const Text('저장')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TBtn extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _TBtn({required this.label, required this.value, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(onTap: () => onTap(value), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? AppTheme.primary : AppTheme.border)),
      child: Text(label, style: TextStyle(fontSize: 13, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
    ));
  }
}
