import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/data_service.dart';
import '../../utils/theme.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('시스템 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 계정 정보
              _Card(title: '계정 정보', child: Column(children: const [
                _InfoRow('운영 업체', '펫신드룸'),
                _InfoRow('관리자 ID', 'petsyndrome'),
                _InfoRow('시스템', '단가 계산 백엔드 v1.0'),
              ])),
              const SizedBox(height: 16),

              // 데이터 안내
              _Card(
                title: '데이터 저장 안내',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(8)),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('데이터는 브라우저 로컬에 영구 저장됩니다.', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                      ]),
                      SizedBox(height: 6),
                      Text('로그아웃 후에도 원물·작업비·포장비·레시피 데이터는\n모두 유지됩니다. 같은 기기·브라우저에서 재접속하면\n기존 데이터를 그대로 사용할 수 있습니다.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
                      SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.warning_amber, size: 14, color: AppTheme.warning),
                        SizedBox(width: 4),
                        Expanded(child: Text('브라우저 캐시 삭제 시 데이터가 초기화될 수 있습니다.', style: TextStyle(fontSize: 11, color: AppTheme.warning))),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // 버전 정보
              _Card(title: '버전 정보', child: Column(children: const [
                _InfoRow('앱 버전', 'v1.0.0'),
                _InfoRow('개발', '펫신드룸 단가 계산 시스템'),
              ])),
              const SizedBox(height: 16),

              // 로그아웃
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
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('로그아웃'),
      content: const Text('로그아웃 하시겠습니까?\n저장된 모든 데이터는 유지됩니다.'),
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
