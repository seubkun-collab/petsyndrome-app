import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

/// 이카운트 견적서 화면
/// 탭1: 견적 작성 (견적이력 선택 → 클립보드 복사)
/// 탭2: 이카운트 전송 (품목코드/거래처코드 매핑 후 자동 전송)
/// 탭3: 이카운트 설정 (API 인증키, 창고코드, 기본 품목코드 등)
class ICountEstimateScreen extends StatefulWidget {
  const ICountEstimateScreen({super.key});
  @override
  State<ICountEstimateScreen> createState() => _ICountEstimateScreenState();
}

class _ICountEstimateScreenState extends State<ICountEstimateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── 공통: 견적 선택 ──
  final Set<String> _selected = {};
  String _search = '';

  // ── 탭1: 견적서 작성 ──
  final _customerNameCtrl = TextEditingController();
  final _customerContactCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _estimateDate = DateTime.now();
  int _validDays = 30;

  // ── 탭2: 이카운트 전송 ──
  // 선택된 각 레시피에 대한 품목코드/거래처코드 매핑
  final Map<String, TextEditingController> _prodCodeCtrls = {};  // recipeId → 품목코드
  final _custCodeCtrl = TextEditingController();   // 거래처코드
  final _custNameCtrl = TextEditingController();   // 거래처명(이카운트 CUST_DES)
  final _whCodeCtrl = TextEditingController();     // 창고코드
  final _empCodeCtrl = TextEditingController();    // 담당자코드
  final _sendNoteCtrl = TextEditingController();   // 비고
  bool _sendLoading = false;
  String? _sendResult;
  bool _sendSuccess = false;
  String? _sessionId;

  // ── 탭3: 이카운트 설정 ──
  final _companyCodeCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _defaultWhCtrl = TextEditingController();   // 기본 창고코드
  final _defaultProdCtrl = TextEditingController(); // 기본 품목코드
  final _defaultEmpCtrl = TextEditingController();  // 기본 담당자코드
  bool _obscureKey = true;
  bool _configLoading = false;
  String? _configStatus;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadICountConfig();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerContactCtrl.dispose();
    _noteCtrl.dispose();
    _prodCodeCtrls.forEach((_, c) => c.dispose());
    _custCodeCtrl.dispose();
    _custNameCtrl.dispose();
    _whCodeCtrl.dispose();
    _empCodeCtrl.dispose();
    _sendNoteCtrl.dispose();
    _companyCodeCtrl.dispose();
    _userIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    _defaultWhCtrl.dispose();
    _defaultProdCtrl.dispose();
    _defaultEmpCtrl.dispose();
    super.dispose();
  }

  // ── 설정 로드 ──
  Future<void> _loadICountConfig() async {
    final cfg = await CloudflareService.icountGetConfig();
    if (cfg != null && mounted) {
      setState(() {
        _companyCodeCtrl.text = cfg['companyCode'] ?? '';
        _userIdCtrl.text = cfg['userId'] ?? '';
        _defaultWhCtrl.text = cfg['defaultWh'] ?? '';
        _defaultProdCtrl.text = cfg['defaultProd'] ?? '';
        _defaultEmpCtrl.text = cfg['defaultEmp'] ?? '';
      });
      // 전송 탭 필드에도 기본값 채우기
      if (_whCodeCtrl.text.isEmpty) _whCodeCtrl.text = cfg['defaultWh'] ?? '';
      if (_empCodeCtrl.text.isEmpty) _empCodeCtrl.text = cfg['defaultEmp'] ?? '';
    }
  }

  // ── 레시피 목록 ──
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

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _prodCodeCtrls.remove(id)?.dispose();
      } else {
        _selected.add(id);
        // 품목코드 컨트롤러 초기화 (기본 품목코드 채우기)
        _prodCodeCtrls[id] = TextEditingController(text: _defaultProdCtrl.text);
      }
    });
  }

  void _selectAll() {
    final all = _recipes.map((r) => r.id).toSet();
    setState(() {
      if (_selected.length == _recipes.length) {
        _prodCodeCtrls.forEach((_, c) => c.dispose());
        _prodCodeCtrls.clear();
        _selected.clear();
      } else {
        for (final r in _recipes) {
          if (!_selected.contains(r.id)) {
            _prodCodeCtrls[r.id] = TextEditingController(text: _defaultProdCtrl.text);
          }
        }
        _selected.addAll(all);
      }
    });
  }

  String _packLabel(Recipe r) {
    switch (r.packagingType) {
      case 'container': return '용기 ${r.packagingWeight.toStringAsFixed(0)}g';
      case 'vinyl': return '비닐 ${r.packagingWeight.toStringAsFixed(0)}g';
      case 'bulk': return '벌크 ${r.bulkMoqKg.toStringAsFixed(0)}kg';
      default: return '${r.packagingWeight.toStringAsFixed(0)}g';
    }
  }

  String _formatDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
  String _formatDateCompact(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';

  // ── 설정 저장 ──
  Future<void> _saveConfig() async {
    final code = _companyCodeCtrl.text.trim();
    final user = _userIdCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();
    if (code.isEmpty || user.isEmpty) {
      setState(() => _configStatus = '회사코드와 아이디를 입력하세요.');
      return;
    }
    setState(() { _configLoading = true; _configStatus = null; });
    final ok = await CloudflareService.icountSaveConfig(
      companyCode: code,
      userId: user,
      apiCertKey: key,
      defaultWh: _defaultWhCtrl.text.trim(),
      defaultProd: _defaultProdCtrl.text.trim(),
      defaultEmp: _defaultEmpCtrl.text.trim(),
    );
    if (mounted) setState(() {
      _configLoading = false;
      _configStatus = ok ? '✅ 설정이 저장되었습니다.' : '❌ 저장에 실패했습니다.';
    });
  }

  // ── 연결 테스트 ──
  Future<void> _testConnection() async {
    final code = _companyCodeCtrl.text.trim();
    final user = _userIdCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();
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
          _configStatus = '✅ 연결 성공! (Zone: $zone) 이제 이카운트 전송이 가능합니다.';
        });
      } else {
        final errMsg = res['error'] as String? ?? '알 수 없는 오류';
        setState(() {
          _configLoading = false;
          _configStatus = '❌ 연결 실패: $errMsg';
        });
      }
    }
  }

  // ── 이카운트 전송 ──
  Future<void> _sendToICount() async {
    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송할 견적 항목을 선택하세요.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final wh = _whCodeCtrl.text.trim();
    if (wh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('창고코드를 입력하세요. (설정 탭에서 기본값 저장 가능)'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    // 품목코드 확인
    for (final r in _selectedRecipes) {
      final prodCode = _prodCodeCtrls[r.id]?.text.trim() ?? '';
      if (prodCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${r.name}" 의 이카운트 품목코드를 입력하세요.'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }

    // 세션 없으면 자동 로그인
    if (_sessionId == null) {
      setState(() { _sendLoading = true; _sendResult = '이카운트 로그인 중...'; });
      final cfg = await CloudflareService.icountGetConfig();
      final res = await CloudflareService.icountGetSession(
        companyCode: cfg?['companyCode'] ?? _companyCodeCtrl.text.trim(),
        userId: cfg?['userId'] ?? _userIdCtrl.text.trim(),
        apiCertKey: '',
      );
      if (res['ok'] != true) {
        setState(() { _sendLoading = false; _sendResult = '❌ 이카운트 로그인 실패: ${res['error']}\n설정 탭에서 연결을 확인하세요.'; _sendSuccess = false; });
        return;
      }
      _sessionId = res['sessionId'] as String?;
    }

    setState(() { _sendLoading = true; _sendResult = null; _sendSuccess = false; });

    final dateStr = _formatDateCompact(_estimateDate);
    final items = _selectedRecipes.map((r) {
      final ingNames = r.items.map((it) => it.ingredientName).join('+');
      final prodCode = _prodCodeCtrls[r.id]?.text.trim() ?? '';
      final prodName = '$ingNames ${_packLabel(r)}';
      return {
        'date': dateStr,
        'customerCode': _custCodeCtrl.text.trim(),
        'customerName': _custNameCtrl.text.trim(),
        'whCode': wh,
        'empCode': _empCodeCtrl.text.trim(),
        'productCode': prodCode,
        'productName': prodName,
        'qty': 1,
        'unitPrice': r.calculatedPrice,
        'note': _sendNoteCtrl.text.trim(),
      };
    }).toList();

    final res = await CloudflareService.icountSendEstimate(
      sessionId: _sessionId!,
      items: items,
    );

    if (mounted) {
      final ok = res['ok'] == true;
      if (!ok) _sessionId = null; // 세션 만료 처리
      final data = res['data'] as Map<String, dynamic>?;
      final successCnt = (data?['Data'] as Map<String, dynamic>?)?['SuccessCnt'] ?? 0;
      final failCnt = (data?['Data'] as Map<String, dynamic>?)?['FailCnt'] ?? 0;
      final slipNos = (data?['Data'] as Map<String, dynamic>?)?['SlipNos'] as List? ?? [];

      setState(() {
        _sendLoading = false;
        _sendSuccess = ok;
        if (ok) {
          _sendResult = '✅ 이카운트 전송 성공!\n성공: $successCnt건 / 실패: $failCnt건'
              + (slipNos.isNotEmpty ? '\n전표번호: ${slipNos.join(', ')}' : '');
        } else {
          _sendResult = '❌ 전송 실패: ${res['error'] ?? '알 수 없는 오류'}\n\n'
              '확인사항:\n'
              '• 품목코드가 이카운트에 등록되어 있는지 확인\n'
              '• 창고코드가 이카운트에 등록되어 있는지 확인\n'
              '• 거래처코드가 있다면 이카운트에 등록된 코드인지 확인';
        }
      });
    }
  }

  // ── 클립보드 복사용 견적서 텍스트 ──
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
    return buf.toString();
  }

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('이카운트 견적서'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: '견적 작성'),
            Tab(icon: Icon(Icons.send_outlined, size: 18), text: '이카운트 전송'),
            Tab(icon: Icon(Icons.settings_outlined, size: 18), text: '설정'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildEstimateTab(),
          _buildSendTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // 탭1: 견적 작성 (클립보드 복사)
  // ══════════════════════════════════════
  Widget _buildEstimateTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측: 레시피 선택
        SizedBox(
          width: 320,
          child: _buildRecipeList(),
        ),
        const VerticalDivider(width: 1),
        // 우측: 견적서 작성
        Expanded(child: _buildEstimateForm()),
      ],
    );
  }

  Widget _buildRecipeList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '레시피 검색...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('${_selected.length}개 선택', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _selectAll,
                child: Text(_selected.length == _recipes.length ? '전체해제' : '전체선택', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _recipes.isEmpty
              ? const Center(child: Text('견적 이력이 없습니다.', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: _recipes.length,
                  itemBuilder: (_, i) {
                    final r = _recipes[i];
                    final sel = _selected.contains(r.id);
                    final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: sel ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: sel ? AppTheme.primary : AppTheme.border),
                      ),
                      child: InkWell(
                        onTap: () => _toggleSelect(r.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: sel,
                                onChanged: (_) => _toggleSelect(r.id),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ingNames, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('${_packLabel(r)}  •  ${Fmt.won(r.calculatedPrice)}원', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    if (r.workerName.isNotEmpty)
                                      Text('고객: ${r.workerName}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEstimateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('견적서 정보', style: AppText.heading3),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: _customerNameCtrl, decoration: const InputDecoration(labelText: '고객명', prefixIcon: Icon(Icons.person_outline, size: 16), isDense: true))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _customerContactCtrl, decoration: const InputDecoration(labelText: '연락처', prefixIcon: Icon(Icons.phone_outlined, size: 16), isDense: true))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _estimateDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setState(() => _estimateDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '견적일', prefixIcon: Icon(Icons.calendar_today_outlined, size: 16), isDense: true),
                        child: Text(_formatDate(_estimateDate), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _validDays,
                      decoration: const InputDecoration(labelText: '유효기간', isDense: true),
                      items: [7, 14, 30, 60, 90].map((d) => DropdownMenuItem(value: d, child: Text('$d일'))).toList(),
                      onChanged: (v) => setState(() => _validDays = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: '비고', prefixIcon: Icon(Icons.notes_outlined, size: 16), isDense: true), maxLines: 2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 선택된 항목 미리보기
          if (_selectedRecipes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Text('견적 항목', style: AppText.heading3),
                    const Spacer(),
                    Text('합계: ${Fmt.won(_totalPrice)}원', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                  ]),
                  const SizedBox(height: 10),
                  ...List.generate(_selectedRecipes.length, (i) {
                    final r = _selectedRecipes[i];
                    final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('${i + 1}.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ingNames, style: const TextStyle(fontSize: 12))),
                          Text(_packLabel(r), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          Text('${Fmt.won(r.calculatedPrice)}원', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 버튼들
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedRecipes.isEmpty ? null : () {
                  showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('견적서 미리보기'),
                    content: SingleChildScrollView(child: SelectableText(_buildEstimateText(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('복사'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _buildEstimateText()));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다.'), behavior: SnackBarBehavior.floating));
                        },
                      ),
                    ],
                  ));
                },
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('미리보기'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedRecipes.isEmpty ? null : () {
                  Clipboard.setData(ClipboardData(text: _buildEstimateText()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('견적서가 클립보드에 복사되었습니다.'), behavior: SnackBarBehavior.floating));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('클립보드 복사'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedRecipes.isEmpty ? null : () {
                  _tabCtrl.animateTo(1);
                },
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('이카운트 전송 →'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // 탭2: 이카운트 전송
  // ══════════════════════════════════════
  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 안내
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.info.withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.info_outline, size: 16, color: AppTheme.info), const SizedBox(width: 6), Text('이카운트 전송 방법', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info))]),
                const SizedBox(height: 8),
                const Text(
                  '1. 견적 작성 탭에서 항목을 먼저 선택하세요.\n'
                  '2. 이카운트에 등록된 품목코드·창고코드·거래처코드를 입력하세요.\n'
                  '3. [이카운트 견적서 전송] 버튼을 클릭하세요.\n\n'
                  '※ 품목코드/창고코드는 이카운트 ERP → 재고 → 품목/창고 메뉴에서 확인\n'
                  '※ 거래처코드는 이카운트 ERP → 거래처 메뉴에서 확인 (없으면 빈칸 가능)',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_selectedRecipes.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                Icon(Icons.check_box_outline_blank, size: 48, color: AppTheme.border),
                const SizedBox(height: 12),
                const Text('견적 작성 탭에서 항목을 선택해주세요.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => _tabCtrl.animateTo(0), child: const Text('← 견적 작성 탭으로')),
              ]),
            )
          else ...[
            // 공통 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('거래처 및 전표 정보', style: AppText.heading3),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _custCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: '거래처코드 (선택)',
                        hintText: '이카운트 거래처코드',
                        prefixIcon: Icon(Icons.business_outlined, size: 16),
                        isDense: true,
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _custNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '거래처명 (선택)',
                        hintText: '표시용 이름',
                        prefixIcon: Icon(Icons.person_outline, size: 16),
                        isDense: true,
                      ),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _whCodeCtrl,
                      decoration: InputDecoration(
                        labelText: '창고코드 *',
                        hintText: '예: 100',
                        helperText: '이카운트에 등록된 창고코드',
                        prefixIcon: const Icon(Icons.warehouse_outlined, size: 16),
                        isDense: true,
                        suffixIcon: _whCodeCtrl.text.isEmpty
                          ? const Icon(Icons.warning_amber, size: 16, color: Colors.orange)
                          : const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _empCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: '담당자코드 (선택)',
                        hintText: '예: petsyndrome',
                        prefixIcon: Icon(Icons.badge_outlined, size: 16),
                        isDense: true,
                      ),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: _estimateDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (d != null) setState(() => _estimateDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '전표일자', prefixIcon: Icon(Icons.calendar_today_outlined, size: 16), isDense: true),
                          child: Text(_formatDate(_estimateDate), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _sendNoteCtrl,
                      decoration: const InputDecoration(labelText: '비고', prefixIcon: Icon(Icons.notes_outlined, size: 16), isDense: true),
                    )),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 품목별 코드 매핑
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Text('품목코드 매핑 *', style: AppText.heading3),
                    const SizedBox(width: 8),
                    Text('(이카운트에 등록된 품목코드 입력)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      '이카운트 ERP → [재고] → [품목] 메뉴에서 품목코드를 확인하세요.\n'
                      '품목이 없으면 이카운트에서 먼저 품목을 등록해야 합니다.',
                      style: TextStyle(fontSize: 11, color: AppTheme.warning),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_selectedRecipes.length, (i) {
                    final r = _selectedRecipes[i];
                    final ingNames = r.items.map((it) => it.ingredientName).join(' + ');
                    _prodCodeCtrls.putIfAbsent(r.id, () => TextEditingController(text: _defaultProdCtrl.text));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i+1}. $ingNames', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${_packLabel(r)}  •  ${Fmt.won(r.calculatedPrice)}원', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _prodCodeCtrls[r.id],
                              decoration: InputDecoration(
                                labelText: '품목코드 *',
                                hintText: '예: PROD001',
                                isDense: true,
                                suffixIcon: (_prodCodeCtrls[r.id]?.text.isEmpty ?? true)
                                  ? const Icon(Icons.warning_amber, size: 14, color: Colors.orange)
                                  : const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 전송 결과
            if (_sendResult != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _sendSuccess ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _sendSuccess ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_sendResult!, style: TextStyle(fontSize: 12, color: _sendSuccess ? AppTheme.primary : AppTheme.danger, height: 1.6)),
              ),
              const SizedBox(height: 16),
            ],

            // 전송 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sendLoading ? null : _sendToICount,
                icon: _sendLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
                label: Text(_sendLoading ? '전송 중...' : '이카운트 견적서 전송'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // 탭3: 설정
  // ══════════════════════════════════════
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 안내
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.info.withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.info_outline, size: 16, color: AppTheme.info), const SizedBox(width: 6), Text('이카운트 ERP API 연동 방법', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info))]),
                const SizedBox(height: 8),
                const Text(
                  '1. 이카운트 로그인 → 정보관리 → 오픈 API → API 인증키 발급\n'
                  '2. 아래에 회사코드(6자리), 담당자 ID, API 인증키 입력 후 [저장]\n'
                  '3. [연결 테스트]로 로그인 확인\n'
                  '4. 기본 창고코드: 이카운트 [재고] → [창고] 메뉴에서 확인\n'
                  '5. 기본 품목코드: 자주 쓰는 품목코드 입력 시 전송탭에서 자동 채워짐',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // API 계정 설정
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('이카운트 API 계정', style: AppText.heading3),
                const SizedBox(height: 16),
                TextField(
                  controller: _companyCodeCtrl,
                  decoration: const InputDecoration(labelText: '회사코드 (6자리)', prefixIcon: Icon(Icons.business_outlined, size: 16), isDense: true, hintText: '예: 610550'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(labelText: '담당자 ID', prefixIcon: Icon(Icons.person_outline, size: 16), isDense: true),
                ),
                const SizedBox(height: 10),
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 기본 코드 설정
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('기본 코드 설정', style: AppText.heading3),
                const SizedBox(height: 6),
                const Text('아래 기본값은 전송 탭에서 자동으로 채워집니다.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: _defaultWhCtrl,
                  decoration: const InputDecoration(
                    labelText: '기본 창고코드',
                    hintText: '예: 100',
                    helperText: '이카운트 [재고] → [창고] 메뉴에서 확인',
                    prefixIcon: Icon(Icons.warehouse_outlined, size: 16),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _defaultProdCtrl,
                  decoration: const InputDecoration(
                    labelText: '기본 품목코드',
                    hintText: '예: FEED001',
                    helperText: '이카운트 [재고] → [품목] 메뉴에서 확인',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 16),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _defaultEmpCtrl,
                  decoration: const InputDecoration(
                    labelText: '기본 담당자코드',
                    hintText: '이카운트 사용자 ID',
                    prefixIcon: Icon(Icons.badge_outlined, size: 16),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 상태 메시지
          if (_configStatus != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _configStatus!.startsWith('✅') ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_configStatus!, style: TextStyle(fontSize: 12, color: _configStatus!.startsWith('✅') ? AppTheme.primary : AppTheme.danger, height: 1.5)),
            ),
            const SizedBox(height: 12),
          ],

          // 버튼
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _configLoading ? null : _testConnection,
                icon: _configLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering_outlined, size: 16),
                label: const Text('연결 테스트'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _configLoading ? null : _saveConfig,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('설정 저장'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
