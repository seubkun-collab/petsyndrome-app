import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/data_service.dart';
import '../../services/cloudflare_service.dart';
import '../../utils/theme.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _pendingCount = 0;

  static final _navItems = [
    _NavItem(icon: Icons.inventory_2_outlined, label: '원물 관리', route: '/admin/ingredients'),
    _NavItem(icon: Icons.build_outlined, label: '작업비 관리', route: '/admin/workcost'),
    _NavItem(icon: Icons.analytics_outlined, label: '원가 조회', route: '/admin/overview'),
    _NavItem(icon: Icons.receipt_long_outlined, label: '단가 견적 이력', route: '/admin/recipes'),
    _NavItem(icon: Icons.description_outlined, label: '이카운트 견적서', route: '/admin/icount'),
    _NavItem(icon: Icons.settings_outlined, label: '시스템 설정', route: '/admin/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final list = await CloudflareService.getPendingAccounts();
      if (mounted) setState(() => _pendingCount = list.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideBar(location: location, navItems: _navItems, pendingCount: _pendingCount),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context, location),
      drawer: _DrawerNav(location: location, navItems: _navItems, pendingCount: _pendingCount),
      body: widget.child,
    );
  }

  AppBar _buildAppBar(BuildContext context, String location) {
    final current = _navItems.where((n) => n.route == location).firstOrNull;
    return AppBar(
      title: Text(current?.label ?? '관리자'),
      actions: [
        if (_pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 20),
                  tooltip: '승인 대기 $_pendingCount건',
                  onPressed: () => context.go('/admin/settings'),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                    child: Text('$_pendingCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: '고객 페이지',
          onPressed: () => context.go('/'),
        ),
      ],
    );
  }
}

class _SideBar extends StatelessWidget {
  final String location;
  final List<_NavItem> navItems;
  final int pendingCount;
  const _SideBar({required this.location, required this.navItems, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pets, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('단가 계산\n백엔드', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('펫신드룸', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Divider(),

          // 메뉴
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              children: navItems.map((item) {
                final selected = location == item.route;
                final badge = item.route == '/admin/settings' && pendingCount > 0 ? pendingCount : 0;
                return _SideNavTile(item: item, selected: selected, badge: badge);
              }).toList(),
            ),
          ),

          const Divider(),
          // 하단
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _SideNavTile(
                  item: _NavItem(icon: Icons.open_in_new, label: '고객 페이지', route: '/'),
                  selected: false,
                ),
                _SideNavTile(
                  item: _NavItem(icon: Icons.logout, label: '로그아웃', route: ''),
                  selected: false,
                  onTap: () async {
                    await DataService.setLoggedIn(false);
                    if (context.mounted) context.go('/admin/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;
  final int badge;
  const _SideNavTile({required this.item, required this.selected, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppTheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap ?? () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: selected ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? AppTheme.primary : AppTheme.textPrimary,
                      )),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerNav extends StatelessWidget {
  final String location;
  final List<_NavItem> navItems;
  final int pendingCount;
  const _DrawerNav({required this.location, required this.navItems, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pets, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                const Text('펫신드룸 단가 계산 백엔드', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const Text('펫신드룸', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: navItems.map((item) {
                final selected = location == item.route;
                final badge = item.route == '/admin/settings' && pendingCount > 0 ? pendingCount : 0;
                return _SideNavTile(item: item, selected: selected, badge: badge);
              }).toList(),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _SideNavTile(
                  item: _NavItem(icon: Icons.open_in_new, label: '고객 페이지', route: '/'),
                  selected: false,
                ),
                _SideNavTile(
                  item: _NavItem(icon: Icons.logout, label: '로그아웃', route: ''),
                  selected: false,
                  onTap: () async {
                    await DataService.setLoggedIn(false);
                    if (context.mounted) {
                      Navigator.pop(context);
                      context.go('/admin/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
