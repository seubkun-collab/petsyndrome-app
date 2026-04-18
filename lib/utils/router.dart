import 'package:go_router/go_router.dart';
import '../screens/admin/login_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/ingredient_screen.dart';
import '../screens/admin/work_cost_screen.dart';
import '../screens/admin/cost_overview_screen.dart';
import '../screens/admin/recipe_list_screen.dart';
import '../screens/admin/system_settings_screen.dart';
import '../screens/customer/customer_screen.dart';
import '../services/data_service.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = DataService.isLoggedIn;
    final isAdmin = state.matchedLocation.startsWith('/admin');
    final isLogin = state.matchedLocation == '/admin/login';

    if (isAdmin && !isLogin && !isLoggedIn) return '/admin/login';
    if (isLogin && isLoggedIn) return '/admin/ingredients';
    return null;
  },
  routes: [
    // 고객 페이지 (메인)
    GoRoute(path: '/', builder: (_, __) => const CustomerScreen()),

    // 관리자 로그인
    GoRoute(path: '/admin/login', builder: (_, __) => const LoginScreen()),

    // 관리자 셸
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/admin/ingredients', builder: (_, __) => const IngredientScreen()),
        GoRoute(path: '/admin/workcost', builder: (_, __) => const WorkCostScreen()),
        GoRoute(path: '/admin/overview', builder: (_, __) => const CostOverviewScreen()),
        GoRoute(path: '/admin/recipes', builder: (_, __) => const RecipeListScreen()),
        GoRoute(path: '/admin/settings', builder: (_, __) => const SystemSettingsScreen()),
      ],
    ),
  ],
);
