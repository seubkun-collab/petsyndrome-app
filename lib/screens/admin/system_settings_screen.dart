import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/data_service.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});
  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _logs = [];
  bool _loadingAccounts = true;
  bool _loadingLogs = true;
  int _tabIndex = 0; // 0=계정관리, 1=로그인기록

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadLogs();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    final list = await CloudflareService.getAllAccounts();
    if (mounted) setState(() { _accounts = list; _loadingAccounts = false; });
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final list = await CloudflareService.getLoginLogs();
    if (mounted) setState(() { _logs = list; _loadingLogs = false; });
  }

  Future<void> _approve(String id, bool approve) async {
    await CloudflareService.approveAccount(id, approve: approve, approvedBy: 'petsyndrome');
    await _loadAccounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? '승인되었습니다.' : '거부되었습니다.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteAccount(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('계정 삭제'),
        content: Text('$name 계정을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white)),
        ],
      ),
    );
    if (ok == true) {
      await CloudflareService.deleteAccount(id);
      await _loadAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('시스템 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 탭 헤더
              Row(children: [
                _TabBtn('👥 계정 관리', 0, _tabIndex, (i) => setState(() => _tabIndex = i)),
                const SizedBox(width: 8),
                _TabBtn('📋 로그인 기록', 1, _tabIndex, (i) => setState(() => _tabIndex = i)),
                const SizedBox(width: 8),
                _TabBtn('⚙️ 시스템', 2, _tabIndex, (i) => setState(() => _tabIndex = i)),
              ]),
              const SizedBox(height: 16),

              if (_tabIndex == 0) _buildAccountsTab(),
              if (_tabIndex == 1) _buildLogsTab(),
              if (_tabIndex == 2) _buildSystemTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    final pending = _accounts.where((a) => a['status'] == 'pending').toList();
    final approved = _accounts.where((a) => a['status'] == 'approved').toList();
    final rejected = _accounts.where((a) => a['status'] == 'rejected').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 대기중 승인
      if (pending.isNotEmpty) ...[
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.warning, borderRadius: BorderRadius.circular(12)),
            child: Text('승인 대기 ${pending.length}건', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('새로고침', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        ...pending.map((a) => _AccountCard(
          account: a,
          onApprove: () => _approve(a['id'], true),
          onReject: () => _approve(a['id'], false),
          onDelete: () => _deleteAccount(a['id'], a['name']),
        )),
        const Divider(height: 24),
      ],

      if (_loadingAccounts)
        const Center(child: CircularProgressIndicator())
      else ...[
        // 승인된 계정
        if (approved.isNotEmpty) ...[
          const Text('✅ 승인된 계정', style: AppText.label),
          const SizedBox(height: 8),
          ...approved.map((a) => _AccountCard(
            account: a,
            onDelete: () => _deleteAccount(a['id'], a['name']),
          )),
          const SizedBox(height: 12),
        ],

        // 거부된 계정
        if (rejected.isNotEmpty) ...[
          const Text('❌ 거부된 계정', style: AppText.label),
          const SizedBox(height: 8),
          ...rejected.map((a) => _AccountCard(
            account: a,
            onDelete: () => _deleteAccount(a['id'], a['name']),
          )),
        ],

        if (_accounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: const Center(child: Text('등록된 계정이 없습니다.', style: AppText.bodySmall)),
          ),
      ],
    ]);
  }

  Widget _buildLogsTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('최근 로그인 기록 (최대 100건)', style: AppText.label),
        const Spacer(),
        TextButton.icon(
          onPressed: _loadLogs,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('새로고침', style: TextStyle(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 8),
      if (_loadingLogs)
        const Center(child: CircularProgressIndicator())
      else if (_logs.isEmpty)
        const Text('로그인 기록이 없습니다.', style: AppText.bodySmall)
      else
        ..._logs.map((log) {
          final type = log['type'] as String? ?? '';
          final name = log['name'] as String? ?? log['id'] as String? ?? '';
          final at = log['at'] as String? ?? '';
          final ip = log['ip'] as String? ?? '';
          final dt = DateTime.tryParse(at);
          final isAdmin = type == 'admin';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isAdmin ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
            ),
            child: Row(children: [
              Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                  size: 16, color: isAdmin ? AppTheme.primary : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? '관리자' : name,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: isAdmin ? AppTheme.primary : AppTheme.textPrimary)),
                Text('${_typeLabel(type)}${ip.isNotEmpty ? ' · $ip' : ''}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ])),
              Text(dt != null ? Fmt.datetime(dt) : at,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          );
        }),
    ]);
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'admin': return '관리자 로그인';
      case 'staff': return '직원 로그인';
      case 'customer': return '고객 로그인';
      default: return t;
    }
  }

  Widget _buildSystemTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Card(title: '계정 정보', child: const Column(children: [
        _InfoRow('운영 업체', '펫신드룸'),
        _InfoRow('관리자 ID', 'petsyndrome'),
        _InfoRow('시스템', '단가 계산 백엔드 v1.1'),
      ])),
      const SizedBox(height: 16),
      _Card(
        title: '데이터 저장 안내',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(8)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.cloud_done_outlined, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Cloudflare KV에 서버 저장', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500)),
            ]),
            SizedBox(height: 6),
            Text('원물·작업비·포장비·레시피 데이터는 서버에 저장되어\n어느 기기에서 접속해도 동일한 데이터를 사용합니다.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      _Card(
        title: '계정 관리',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('로그아웃해도 저장된 데이터는 유지됩니다.', style: AppText.bodySmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, size: 16, color: AppTheme.danger),
            label: const Text('로그아웃', style: TextStyle(color: AppTheme.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
          ),
        ]),
      ),
    ]);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('로그아웃'),
      content: const Text('로그아웃 하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () async {
            await DataService.setLoggedIn(false);
            if (context.mounted) context.go('/admin/login');
          },
          child: const Text('로그아웃'),
        ),
      ],
    ));
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback? onApprove, onReject, onDelete;
  const _AccountCard({required this.account, this.onApprove, this.onReject, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = account['status'] as String? ?? 'pending';
    final role = account['role'] as String? ?? 'staff';
    final name = account['name'] as String? ?? '';
    final createdAt = account['createdAt'] as String? ?? '';
    final approvedAt = account['approvedAt'] as String? ?? '';
    final approvedBy = account['approvedBy'] as String? ?? '';
    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    final statusColor = isPending ? AppTheme.warning : isApproved ? AppTheme.primary : AppTheme.danger;
    final statusLabel = isPending ? '대기중' : isApproved ? '승인됨' : '거부됨';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPending ? AppTheme.warning.withValues(alpha: 0.5) : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(role == 'customer' ? Icons.person_outline : Icons.badge_outlined,
              size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(role == 'customer' ? '고객' : '직원', style: const TextStyle(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          if (onDelete != null)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text('가입: ${_fmt(createdAt)}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        if (approvedAt.isNotEmpty)
          Text('처리: ${_fmt(approvedAt)} by $approvedBy', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        if (isPending && (onApprove != null || onReject != null)) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (onApprove != null) ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check, size: 14),
              label: const Text('승인', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
              ),
            ),
            const SizedBox(width: 8),
            if (onReject != null) OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 14),
              label: const Text('거부', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  const _TabBtn(this.label, this.index, this.current, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.heading3),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: AppText.bodySmall)),
      Expanded(child: Text(value, style: AppText.body)),
    ]),
  );
}
