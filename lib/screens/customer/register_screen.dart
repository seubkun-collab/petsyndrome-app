import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
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
                // 로고
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.pets, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                const Text('펫신드룸 가입 신청', style: AppText.heading2),
                const SizedBox(height: 4),
                const Text('관리자 승인 후 로그인 가능합니다', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 28),

                // 가입 폼
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
                      const Text('직원 가입 신청', style: AppText.heading3),
                      const SizedBox(height: 8),
                      const Text(
                        '가입 신청 후 관리자(petsyndrome) 승인 시 로그인 가능합니다.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                          hintText: '실명을 입력하세요',
                        ),
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinCtrl,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'PIN 번호 (4자리 이상)',
                          prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinConfirmCtrl,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'PIN 확인',
                          prefixIcon: Icon(Icons.pin_outlined, size: 18),
                        ),
                        onSubmitted: (_) => _register(),
                      ),

                      // 에러/성공 메시지
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
                      if (_success != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 16),
                                  SizedBox(width: 6),
                                  Text('신청 완료', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_success!, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('가입 신청'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 이미 계정이 있으면 로그인
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('이미 계정이 있으신가요?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => context.go('/admin/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('로그인하기 →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
