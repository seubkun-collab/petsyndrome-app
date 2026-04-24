import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/data_service.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 0=관리자로그인 1=직원로그인 2=직원회원가입
  int _tab = 0;

  // 관리자 로그인
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  // 직원 로그인/회원가입 공통
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _adminLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await CloudflareService.loginAccount(
        name: _idCtrl.text.trim(),
        pin: _pwCtrl.text,
        role: 'admin',
      );
      // admin은 서버 API가 없으니 로컬 체크 후 서버 기록만 남김
      if (DataService.checkLogin(_idCtrl.text.trim(), _pwCtrl.text)) {
        await DataService.setLoggedIn(true);
        if (mounted) context.go('/admin/ingredients');
      } else {
        setState(() { _error = '아이디 또는 비밀번호가 올바르지 않습니다.'; });
      }
    } catch (_) {
      if (DataService.checkLogin(_idCtrl.text.trim(), _pwCtrl.text)) {
        await DataService.setLoggedIn(true);
        if (mounted) context.go('/admin/ingredients');
      } else {
        setState(() { _error = '아이디 또는 비밀번호가 올바르지 않습니다.'; });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _staffLogin() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty || pin.isEmpty) {
      setState(() => _error = '이름과 PIN을 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await CloudflareService.loginAccount(name: name, pin: pin, role: 'staff');
    if (mounted) setState(() => _loading = false);
    if (res['ok'] == true) {
      await DataService.setCurrentWorker(name);
      await DataService.setLoggedIn(true);
      if (mounted) context.go('/admin/ingredients');
    } else {
      setState(() => _error = res['error'] as String? ?? '로그인에 실패했습니다.');
    }
  }

  Future<void> _staffRegister() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final pinConfirm = _pinConfirmCtrl.text.trim();
    if (name.isEmpty || pin.isEmpty) {
      setState(() => _error = '이름과 PIN을 입력해주세요.');
      return;
    }
    if (pin != pinConfirm) {
      setState(() => _error = 'PIN이 일치하지 않습니다.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'PIN은 4자리 이상이어야 합니다.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    final res = await CloudflareService.registerAccount(name: name, pin: pin, role: 'staff');
    if (mounted) setState(() => _loading = false);
    if (res['ok'] == true) {
      setState(() {
        _success = '가입 신청 완료! 관리자(petsyndrome) 승인 후 로그인 가능합니다.';
        _nameCtrl.clear();
        _pinCtrl.clear();
        _pinConfirmCtrl.clear();
        _tab = 1;
      });
    } else {
      setState(() => _error = res['error'] as String? ?? '가입에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.pets, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                const Text('펫신드룸 단가 계산 백엔드', style: AppText.heading2),
                const SizedBox(height: 4),
                const Text('펫신드룸', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 28),

                // 탭 선택
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    _TabChip('관리자', 0, _tab, (i) => setState(() { _tab = i; _error = null; _success = null; })),
                    _TabChip('직원 로그인', 1, _tab, (i) => setState(() { _tab = i; _error = null; _success = null; })),
                    _TabChip('직원 가입', 2, _tab, (i) => setState(() { _tab = i; _error = null; _success = null; })),
                  ]),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_tab == 0) ..._buildAdminForm(),
                      if (_tab == 1) ..._buildStaffLoginForm(),
                      if (_tab == 2) ..._buildStaffRegisterForm(),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text(_success!, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                        ),
                      ],

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : (_tab == 0 ? _adminLogin : _tab == 1 ? _staffLogin : _staffRegister),
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_tab == 2 ? '가입 신청' : '로그인'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('고객 단가 계산기로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAdminForm() => [
    const Text('관리자 로그인', style: AppText.heading3),
    const SizedBox(height: 16),
    TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: '아이디', prefixIcon: Icon(Icons.person_outline, size: 18)), onSubmitted: (_) => _adminLogin()),
    const SizedBox(height: 12),
    TextField(
      controller: _pwCtrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: '비밀번호',
        prefixIcon: const Icon(Icons.lock_outline, size: 18),
        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
      ),
      onSubmitted: (_) => _adminLogin(),
    ),
  ];

  List<Widget> _buildStaffLoginForm() => [
    const Text('직원 로그인', style: AppText.heading3),
    const SizedBox(height: 8),
    const Text('등록된 이름과 PIN으로 로그인하세요.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    const SizedBox(height: 16),
    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '이름', prefixIcon: Icon(Icons.badge_outlined, size: 18)), onSubmitted: (_) => _staffLogin()),
    const SizedBox(height: 12),
    TextField(
      controller: _pinCtrl,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'PIN 번호',
        prefixIcon: const Icon(Icons.pin_outlined, size: 18),
        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
      ),
      onSubmitted: (_) => _staffLogin(),
    ),
  ];

  List<Widget> _buildStaffRegisterForm() => [
    const Text('직원 가입 신청', style: AppText.heading3),
    const SizedBox(height: 8),
    const Text('가입 신청 후 관리자(petsyndrome) 승인 시 로그인 가능합니다.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    const SizedBox(height: 16),
    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '이름', prefixIcon: Icon(Icons.badge_outlined, size: 18))),
    const SizedBox(height: 12),
    TextField(
      controller: _pinCtrl,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'PIN 번호 (4자리 이상)',
        prefixIcon: const Icon(Icons.pin_outlined, size: 18),
        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _pinConfirmCtrl,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'PIN 확인', prefixIcon: Icon(Icons.pin_outlined, size: 18)),
      onSubmitted: (_) => _staffRegister(),
    ),
  ];
}

class _TabChip extends StatelessWidget {
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  const _TabChip(this.label, this.index, this.current, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    ));
  }
}
