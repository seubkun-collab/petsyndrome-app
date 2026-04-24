import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/work_cost.dart';
import '../../models/packaging.dart';
import '../../services/data_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

class WorkCostScreen extends StatefulWidget {
  const WorkCostScreen({super.key});
  @override
  State<WorkCostScreen> createState() => _WorkCostScreenState();
}

class _WorkCostScreenState extends State<WorkCostScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('작업비 관리'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '동결 작업비'),
            Tab(text: '포장 작업비'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DryingCostTab(onChanged: () => setState(() {})),
          _PackagingCostTab(onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

// ── 동결 작업비 탭 ──
class _DryingCostTab extends StatefulWidget {
  final VoidCallback onChanged;
  const _DryingCostTab({required this.onChanged});
  @override
  State<_DryingCostTab> createState() => _DryingCostTabState();
}

class _DryingCostTabState extends State<_DryingCostTab> {
  WorkCost? _wc;          // nullable로 변경 — 로딩 전 null
  bool _loading = true;
  final _dryingCtrl = TextEditingController();
  final _mixingCtrl = TextEditingController();
  final _cuttingCtrl = TextEditingController();
  final _lossCtrl = TextEditingController();
  final _marginCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await DataService.refreshAll();
    if (mounted) {
      _load();
      setState(() => _loading = false);
    }
  }

  void _load() {
    final wc = DataService.getWorkCost();
    _wc = wc;
    _dryingCtrl.text = wc.dryingCost.toStringAsFixed(0);
    _mixingCtrl.text = wc.mixingCost.toStringAsFixed(0);
    _cuttingCtrl.text = wc.cuttingCost.toStringAsFixed(0);
    _lossCtrl.text = (wc.cuttingLossRate * 100).toStringAsFixed(1);
    _marginCtrl.text = (wc.marginRate * 100).toStringAsFixed(1);
  }

  Future<void> _save() async {
    final wc0 = _wc;
    if (wc0 == null) return;
    final drying = double.tryParse(_dryingCtrl.text.trim()) ?? wc0.dryingCost;
    final mixing = double.tryParse(_mixingCtrl.text.trim()) ?? wc0.mixingCost;
    final cutting = double.tryParse(_cuttingCtrl.text.trim()) ?? wc0.cuttingCost;
    final loss = (double.tryParse(_lossCtrl.text.trim()) ?? (wc0.cuttingLossRate * 100)) / 100.0;
    final margin = (double.tryParse(_marginCtrl.text.trim()) ?? (wc0.marginRate * 100)) / 100.0;
    final changedBy = DataService.currentWorker.isNotEmpty ? DataService.currentWorker : '관리자';

    final updated = WorkCost(
      id: 'default',
      dryingCost: drying,
      mixingCost: mixing,
      cuttingCost: cutting,
      cuttingLossRate: loss,
      marginRate: margin,
      changedBy: changedBy,
    );
    await DataService.saveWorkCost(updated, changedBy: changedBy);
    setState(() { _wc = updated; _saved = true; });
    widget.onChanged();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  void _showHistory() {
    final wc0 = _wc;
    if (wc0 == null) return;
    showDialog(
      context: context,
      builder: (_) => _WorkCostHistoryDialog(history: wc0.history),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나 _wc가 아직 null이면 스피너 표시
    if (_loading || _wc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final wc = _wc!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: '동결 작업비 설정',
              subtitle: '마지막 수정: ${Fmt.datetime(wc.updatedAt)} (${wc.changedBy})',
              trailingButton: wc.history.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () => _showHistory(),
                      icon: const Icon(Icons.history, size: 14),
                      label: Text('변경이력 ${wc.history.length}건', style: const TextStyle(fontSize: 12)),
                    )
                  : null,
              child: Column(
                children: [
                  _CostField(label: '건조비', ctrl: _dryingCtrl, unit: '원/kg', tooltip: '동결건조 시 kg당 건조 비용'),
                  _CostField(label: '배합작업비', ctrl: _mixingCtrl, unit: '원/kg', tooltip: '배합 제품 제조 시 추가 작업비'),
                  _CostField(label: '절단비', ctrl: _cuttingCtrl, unit: '원/kg', tooltip: '원물 절단/가공 시 kg당 비용'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '로스율 & 마진율',
              child: Column(
                children: [
                  _CostField(label: '절단 로스율', ctrl: _lossCtrl, unit: '%', tooltip: '절단/가공 시 손실율 (예: 5 = 5%)'),
                  _CostField(label: '마진율', ctrl: _marginCtrl, unit: '%', tooltip: '최종 단가에 적용할 마진율 (예: 30 = 30%)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 미리보기
            _SectionCard(
              title: '원가 공식 미리보기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormulaRow('단미 원가', '((원물가+절단비)/(1-로스율)+건조비)/(1-수분)'),
                  const SizedBox(height: 6),
                  _FormulaRow('배합 원가', '((원물가+배합비+절단비)/(1-로스율)+건조비)/(1-수분)'),
                  const SizedBox(height: 6),
                  _FormulaRow('최종 단가', '원가 / (1 - 마진율)'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_saved) ...[
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('저장되었습니다', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                  const Spacer(),
                ],
                if (!_saved) const Spacer(),
                if (DataService.currentWorker.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('수정자: ${DataService.currentWorker}', style: AppText.bodySmall),
                  ),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostField extends StatelessWidget {
  final String label, unit;
  final TextEditingController ctrl;
  final String? tooltip;
  const _CostField({required this.label, required this.ctrl, required this.unit, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(label, style: AppText.body),
                if (tooltip != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(message: tooltip!, child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: unit,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String label, formula;
  const _FormulaRow(this.label, this.formula);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: AppText.bodySmall)),
          Expanded(child: Text(formula, style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontFamily: 'monospace'))),
        ],
      );
}

// ── 포장 작업비 탭 ──
class _PackagingCostTab extends StatefulWidget {
  final VoidCallback onChanged;
  const _PackagingCostTab({required this.onChanged});
  @override
  State<_PackagingCostTab> createState() => _PackagingCostTabState();
}

class _PackagingCostTabState extends State<_PackagingCostTab> {
  List<Packaging> get _packagings => DataService.getPackagings(activeOnly: false);

  void _openForm([Packaging? pkg]) {
    showDialog(
      context: context,
      builder: (_) => _PackagingFormDialog(packaging: pkg, onSaved: () { setState(() {}); widget.onChanged(); }),
    );
  }

  Future<void> _delete(Packaging pkg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${pkg.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) {
      await DataService.deletePackaging(pkg.id);
      setState(() {}); widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkgs = _packagings;
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('포장 추가', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                SizedBox(width: 100, child: Text('구분', style: AppText.label)),
                Expanded(flex: 3, child: Text('품목명', style: AppText.label)),
                Expanded(flex: 2, child: Text('통가격(원)', style: AppText.label)),
                Expanded(flex: 2, child: Text('포장비(원)', style: AppText.label)),
                Expanded(flex: 2, child: Text('용량(cc)', style: AppText.label)),
                SizedBox(width: 80, child: Text('관리', style: AppText.label)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pkgs.isEmpty
                ? const Center(child: Text('등록된 포장이 없습니다.', style: AppText.bodySmall))
                : ListView.separated(
                    itemCount: pkgs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _PackagingRow(pkg: pkgs[i], onEdit: () => _openForm(pkgs[i]), onDelete: () => _delete(pkgs[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PackagingRow extends StatelessWidget {
  final Packaging pkg;
  final VoidCallback onEdit, onDelete;
  const _PackagingRow({required this.pkg, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 100, child: _CatBadge(cat: pkg.category)),
          Expanded(flex: 3, child: Text(pkg.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(Fmt.won(pkg.containerPrice), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(Fmt.won(pkg.packagingCost), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(pkg.volumeCC != null ? '${pkg.volumeCC}cc' : '-', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatBadge extends StatelessWidget {
  final String cat;
  const _CatBadge({required this.cat});
  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (cat) {
      case 'container': c = AppTheme.primary; label = '통포장'; break;
      case 'vinyl': c = AppTheme.info; label = '비닐'; break;
      case 'sample': c = AppTheme.warning; label = '샘플'; break;
      default: c = AppTheme.textSecondary; label = '수작업';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _PackagingFormDialog extends StatefulWidget {
  final Packaging? packaging;
  final VoidCallback onSaved;
  const _PackagingFormDialog({this.packaging, required this.onSaved});
  @override
  State<_PackagingFormDialog> createState() => _PackagingFormDialogState();
}

class _PackagingFormDialogState extends State<_PackagingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _category;
  final _nameCtrl = TextEditingController();
  final _containerPriceCtrl = TextEditingController();
  final _packagingCostCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.packaging;
    _category = p?.category ?? 'container';
    if (p != null) {
      _nameCtrl.text = p.name;
      _containerPriceCtrl.text = p.containerPrice.toStringAsFixed(0);
      _packagingCostCtrl.text = p.packagingCost.toStringAsFixed(0);
      _volumeCtrl.text = p.volumeCC?.toString() ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pkg = Packaging(
      id: widget.packaging?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      category: _category,
      containerPrice: double.tryParse(_containerPriceCtrl.text.trim()) ?? 0,
      packagingCost: double.tryParse(_packagingCostCtrl.text.trim()) ?? 0,
      volumeCC: _volumeCtrl.text.trim().isEmpty ? null : int.tryParse(_volumeCtrl.text.trim()),
      sortOrder: widget.packaging?.sortOrder ?? DataService.getPackagings(activeOnly: false).length,
    );
    await DataService.savePackaging(pkg);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(widget.packaging == null ? '포장 추가' : '포장 수정', style: AppText.heading3),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                // 구분
                const Text('포장 구분', style: AppText.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in [('container', '통포장'), ('vinyl', '비닐'), ('sample', '샘플'), ('manual', '수작업')])
                      _TypeBtn(label: c.$2, value: c.$1, current: _category, onTap: (v) => setState(() => _category = v)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: '품목명 *', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '필수 입력' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _containerPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '통가격(원)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _packagingCostCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '포장비(원)', isDense: true),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '필수 입력' : null,
                      ),
                    ),
                  ],
                ),
                if (_category == 'container') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _volumeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '용량(cc)', isDense: true),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: _save, child: const Text('저장')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _TypeBtn({required this.label, required this.value, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailingButton;
  const _SectionCard({required this.title, this.subtitle, required this.child, this.trailingButton});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.heading3)),
              if (trailingButton != null) trailingButton!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppText.bodySmall),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// 작업비 변경이력 다이얼로그
class _WorkCostHistoryDialog extends StatelessWidget {
  final List<WorkCostHistory> history;
  const _WorkCostHistoryDialog({required this.history});

  @override
  Widget build(BuildContext context) {
    final sorted = [...history]..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 500),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('작업비 변경이력', style: AppText.heading3)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), iconSize: 20),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final h = sorted[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(Fmt.datetime(h.changedAt), style: AppText.bodySmall),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(h.changedBy, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(h.note, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          '건조비 ${h.dryingCost.toStringAsFixed(0)}원 | 배합비 ${h.mixingCost.toStringAsFixed(0)}원 | 절단비 ${h.cuttingCost.toStringAsFixed(0)}원 | 로스 ${(h.cuttingLossRate*100).toStringAsFixed(1)}% | 마진 ${(h.marginRate*100).toStringAsFixed(1)}%',
                          style: AppText.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
