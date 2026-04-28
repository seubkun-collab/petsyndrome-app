import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

/// 이카운트 견적서 작성 화면
/// 고객 견적 이력에서 항목을 선택해 이카운트 ERP로 자동 전송합니다.
class ICountEstimateScreen extends StatefulWidget {
  const ICountEstimateScreen({super.key});
  @override
  State<ICountEstimateScreen> createState() => _ICountEstimateScreenState();
}

class _ICountEstimateScreenState extends State<ICountEstimateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // 항목 선택
  final Set<String> _selected = {};
  String _search = '';

  // 견적서 헤더
  final _customerNameCtrl = TextEditingController();
  final _customerContactCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _estimateDate = DateTime.now();
  int _validDays = 30;

  // 이카운트 설정
  final _companyCodeCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _configLoading = false;
  bool _sendLoading = false;
  String? _sessionId;
  String? _configStatus;
  String? _sendResult;
  bool _sendSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadICountConfig();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerContactCtrl.dispose();
    _noteCtrl.dispose();
    _companyCodeCtrl.dispose();
    _userIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadICountConfig() async {
    final cfg = await CloudflareService.icountGetConfig();
    if (cfg != null && mounted) {
      setState(() {
        _companyCodeCtrl.text = cfg['companyCode'] ?? '';
        _userIdCtrl.text = cfg['userId'] ?? '';
        // API 인증키는 서버에서 마스킹으로 오므로 빈칸 유지 (사용자가 매번 입력)
      });
    }
  }

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

  double get _totalPrice =>
      _selectedRecipes.fold(0.0, (sum, r) => sum + r.calculatedPrice);

  void _toggleSelect(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _selectAll() {
    final all = _recipes.map((r) => r.id).toSet();
    setState(() => _selected.length == _recipes.length ? _selected.clear() : _selected.addAll(all));
  }

  Future<void> _saveConfig() async {
    final code = _companyCodeCtrl.text.trim();
    final user = _userIdCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();
    if (code.isEmpty || user.isEmpty || key.isEmpty) {
      setState(() => _configStatus = '회사코드, 아이디, API 인증키를 모두 입력하세요.');
      return;
    }
    setState(() { _configLoading = true; _configStatus = null; });
    final ok = await CloudflareService.icountSaveConfig(
      companyCode: code, userId: user, apiCertKey: key,
    );
    if (mounted) setState(() {
      _configLoading = false;
      _configStatus = ok ? '✅ 설정이 저장되었습니다.' : '❌ 저장에 실패했습니다.';
    });
  }

  Future<void> _testConnection() async {
    final code = _companyCodeCtrl.text.trim();
    final user = _userIdCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim(); // 비어있으면 서버가 저장된 키 사용
    if (code.isEmpty || user.isEmpty) {
      setState(() => _configStatus = '회사코드와 아이디를 입력하세요.');
      return;
    }
    setState(() { _configLoading = true; _configStatus = 'Zone 조회 및 연결 테스트 중...'; _sessionId = null; });
    final res = await CloudflareService.icountGetSession(
      companyCode: code, userId: user, apiCertKey: key,
    );
    if (mounted) {
      if (res['ok'] == true) {
        final sessionId = res['sessionId'] as String?;
        final zone = res['zone'] as String?;
        setState(() {
          _sessionId = sessionId;
          _configLoading = false;
          _configStatus = '✅ 연결 성공! (Zone: $zone) 세션 발급 완료. 이제 견적 전송이 가능합니다.';
        });
      } else {
        final errMsg = res['error'] as String? ?? (res['raw'] != null ? res['raw'].toString() : '알 수 없는 오류');
        setState(() {
          _configLoading = false;
          _configStatus = '❌ 연결 실패: $errMsg';
        });
      }
    }
  }

  Future<void> _sendToICount() async {
    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송할 견적 항목을 선택하세요.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // 세션이 없으면 먼저 로그인
    if (_sessionId == null) {
      await _testConnection();
      if (_sessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이카운트 연결에 실패했습니다. 설정을 확인하세요.'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }

    setState(() { _sendLoading = true; _sendResult = null; _sendSuccess = false; });

    final today = DateTime.now();
    final dateStr = '${today.year}${today.month.toString().padLeft(2,'0')}${today.day.toString().padLeft(2,'0')}';
    // zone은 세션 로그인 시 자동으로 결정됨 (worker.js에서 처리)

    final items = _selectedRecipes.map((r) {
      final ingNames = r.items.map((it) => it.ingredientName).join('+');
      return {
        'date': dateStr,
        'customerName': _customerNameCtrl.text.trim(),
        'customerCode': '',
        'productCode': r.id.substring(0, 8),
        'productName': '$ingNames ${_packLabel(r)}',
        'qty': 1,
        'unitPrice': r.calculatedPrice,
        'note': _noteCtrl.text.trim(),
      };
    }).toList();

    final res = await CloudflareService.icountSendEstimate(
      sessionId: _sessionId!,
      items: items,
    );

    if (mounted) {
      final ok = res['ok'] == true;
      final data = res['data'] as Map<String, dynamic>?;
      final successCnt = (data?['Data'] as Map<String, dynamic>?)?['SuccessCnt'];
      final failCnt = (data?['Data'] as Map<String, dynamic>?)?['FailCnt'];

      setState(() {
        _sendLoading = false;
        _sendSuccess = ok;
        if (ok) {
          _sendResult = '✅ 이카운트 전송 성공!\n성공: $successCnt건 / 실패: $failCnt건';
        } else {
          // 세션 만료 시 재시도
          _sessionId = null;
          _sendResult = '❌ 전송 실패: ${res['error'] ?? '알 수 없는 오류'}\n세션이 만료되었을 수 있습니다. 다시 시도하세요.';
        }
      });
    }
  }

  String _buildEstimateText() {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('           펫신드룸 견적서');
    buf.writeln('═══════════════════════════════════');
    buf.writeln('견적일: ${_formatDate(_estimateDate)}');
    final expire = _estimateDate.add(Duration(days: _validDays));
    buf.writeln('유효기간: ${_formatDate(expire)} (${_validDays}일)');
    if (_customerNameCtrl.text.isNotEmpty) buf.writeln('고객명: ${_customerNameCtrl.text.trim()}');
    if (_customerContactCtrl.text.isNotEmpty) buf.writeln('연락처: ${_customerContactCtrl.text.trim()}');
    buf.writeln('───────────────────────────────────');
    buf.writeln('No. | 품목 | 포장 | 단가');
    buf.writeln('───────────────────────────────────');
    for (int i = 0; i < _selectedRecipes.length; i++) {
      final r = _selectedRecipes[i];
      final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
      buf.writeln('${i + 1}. $ingNames');
      buf.writeln('   ${_packLabel(r)} | ${Fmt.won(r.calculatedPrice)}');
    }
    buf.writeln('───────────────────────────────────');
    buf.writeln('합계: ${Fmt.won(_totalPrice)}');
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
      case 'container': return '용기포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
      case 'vinyl': return '비닐포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
      case 'bulk': return '벌크 ${r.bulkMoqKg.toStringAsFixed(0)}kg';
      default: return '포장 (${r.packagingWeight.toStringAsFixed(0)}g)';
    }
  }

  String _formatDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

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
        content: Text('견적서가 클립보드에 복사되었습니다.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // 헤더
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('이카운트 견적서', style: AppText.heading3),
                    Text('견적 이력 선택 → 이카운트 ERP 자동 전송', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                  const Spacer(),
                  // 세션 상태 표시
                  if (_sessionId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: const [
                        Icon(Icons.link, size: 12, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('이카운트 연결됨', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabCtrl,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '견적 선택 & 전송'),
                    Tab(text: '이카운트 설정'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildEstimateTab(),
                _buildConfigTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateTab() {
    final recipes = _recipes;
    final allSelected = recipes.isNotEmpty && _selected.length == recipes.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 견적 목록
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
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
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: AppTheme.primary, size: 15),
                    const SizedBox(width: 6),
                    Text('${_selected.length}개 선택됨 · 합계 ${Fmt.won(_totalPrice)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                  ]),
                ),
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
                                border: Border.all(color: sel ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                                      size: 18, color: sel ? AppTheme.primary : AppTheme.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ingNames, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_packLabel(r)} · ${r.workerName.isNotEmpty ? r.workerName : "미기록"} · ${Fmt.date(r.createdAt)}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(Fmt.won(r.calculatedPrice),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
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

        // 오른쪽: 액션 패널
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
                const SizedBox(height: 14),
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
                TextField(
                  controller: _customerContactCtrl,
                  decoration: const InputDecoration(
                    labelText: '연락처 (선택)',
                    prefixIcon: Icon(Icons.phone_outlined, size: 16),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _estimateDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _estimateDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('견적일', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        Text(_formatDate(_estimateDate), style: const TextStyle(fontSize: 13)),
                      ])),
                      const Icon(Icons.edit_outlined, size: 13, color: AppTheme.textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
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
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '비고',
                    prefixIcon: Icon(Icons.notes_outlined, size: 16),
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                if (_selectedRecipes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_selectedRecipes.length}개 항목 선택',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(Fmt.won(_totalPrice),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // 이카운트 전송 버튼
                ElevatedButton.icon(
                  onPressed: (_sendLoading || _selectedRecipes.isEmpty) ? null : _sendToICount,
                  icon: _sendLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 16),
                  label: Text(_sendLoading ? '전송 중...' : '이카운트로 전송'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),

                if (_sendResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _sendSuccess
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_sendResult!,
                        style: TextStyle(fontSize: 12,
                            color: _sendSuccess ? AppTheme.primary : AppTheme.danger)),
                  ),
                ],

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selectedRecipes.isEmpty ? null : _copyToClipboard,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('클립보드 복사'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                ),

                const SizedBox(height: 6),
                // 연결 안 된 경우 설정 탭으로 유도
                if (_sessionId == null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined, color: AppTheme.warning, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('이카운트 미연결', style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => _tabCtrl.animateTo(1),
                          child: const Text('설정 탭에서 API 정보를 입력하세요 →',
                              style: TextStyle(fontSize: 11, color: AppTheme.info, decoration: TextDecoration.underline)),
                        ),
                      ])),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 배너
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 16),
                    SizedBox(width: 6),
                    Text('이카운트 ERP API 연동 방법', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info)),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    '1. 이카운트 로그인 → 정보관리 → 오픈 API\n'
                    '2. API 인증키 발급 (테스트키 가능)\n'
                    '3. 아래에 회사코드(6자리), 담당자 ID, API 인증키 입력\n'
                    '4. [연결 테스트] 버튼으로 Zone 자동 감지 및 세션 확인 후 견적 전송',
                    style: TextStyle(fontSize: 12, color: AppTheme.info, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('이카운트 ERP 계정 정보', style: AppText.heading3),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _companyCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: '회사코드 (6자리)',
                          prefixIcon: Icon(Icons.business_outlined, size: 16),
                          isDense: true,
                          hintText: '예: 123456',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userIdCtrl,
                    decoration: const InputDecoration(
                      labelText: '담당자 ID',
                      prefixIcon: Icon(Icons.person_outline, size: 16),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API 인증키',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 16),
                      isDense: true,
                      hintText: '저장된 키 사용 (변경 시에만 입력)',
                      helperText: '비워두면 이전에 저장한 API 인증키를 자동 사용합니다',
                      helperStyle: const TextStyle(fontSize: 11),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),

                  if (_configStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _configStatus!.startsWith('✅')
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : _configStatus!.startsWith('⚠️')
                                ? AppTheme.warning.withValues(alpha: 0.08)
                                : AppTheme.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_configStatus!,
                          style: TextStyle(
                              fontSize: 12,
                              color: _configStatus!.startsWith('✅')
                                  ? AppTheme.primary
                                  : _configStatus!.startsWith('⚠️')
                                      ? AppTheme.warning
                                      : AppTheme.danger)),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _configLoading ? null : _testConnection,
                        icon: _configLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.link, size: 16),
                        label: const Text('연결 테스트'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _configLoading ? null : _saveConfig,
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('설정 저장'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Zone 설명
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Zone 번호 확인 방법', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text(
                    '이카운트 로그인 후 주소창 URL을 확인하세요.\n'
                    'oapi1.ecount.com → Zone: 1\n'
                    'oapi2.ecount.com → Zone: 2\n'
                    '모르면 1로 시작해서 연결 테스트로 확인하세요.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
