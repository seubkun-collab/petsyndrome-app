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
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty || pin.isEmpty) {
      setState(() => _error = '아이디(이름)와 비밀번호(PIN)를 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // 관리자 체크 (petsyndrome + 로컬 비밀번호)
    final isAdmin = DataService.checkLogin(name, pin);
    if (isAdmin) {
      try {
        await CloudflareService.loginAccount(name: name, pin: pin, role: 'admin');
      } catch (_) {}
      await DataService.setLoggedIn(true);
      if (mounted) context.go('/admin/ingredients');
      return;
    }

    // 직원 체크 (서버 API)
    final res = await CloudflareService.loginAccount(name: name, pin: pin, role: 'staff');
    if (mounted) setState(() => _loading = false);

    if (res['ok'] == true) {
      await DataService.setCurrentWorker(name);
      await DataService.setLoggedIn(true);
      if (mounted) context.go('/admin/ingredients');
    } else {
      setState(() => _error = res['error'] as String? ?? '아이디 또는 비밀번호가 올바르지 않습니다.');
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
                // 로고
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

                // 로그인 폼
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('로그인', style: AppText.heading3),
                      const SizedBox(height: 8),
                      const Text(
                        '관리자 또는 승인된 직원 계정으로 로그인하세요.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '아이디 (이름)',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinCtrl,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '비밀번호 (PIN)',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                        ),
                      ],

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('로그인'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 가입 링크
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('계정이 없으신가요?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/register'),
                        child: const Text(
                          '가입 신청하기 →',
                          style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('고객 단가 계산기로 이동'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
