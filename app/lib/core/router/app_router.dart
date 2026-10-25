import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/access_status.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/no_access_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/items/presentation/stock_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shopping_list/presentation/shopping_list_page.dart';
import 'home_shell.dart';

/// 画面遷移の定義。画面を増やすときはここに GoRoute を追加する。
final appRouterProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier<AccessStatus>(ref.read(accessStatusProvider));
  ref.listen<AccessStatus>(accessStatusProvider, (previous, next) {
    if (next == AccessStatus.denied) {
      ref
          .read(deniedEmailProvider.notifier)
          .set(ref.read(currentUserProvider)?.email);
    }
    status.value = next;
  });

  final router = GoRouter(
    initialLocation: '/stock',
    refreshListenable: status,
    redirect: (context, state) => redirectFor(status.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/no_access',
        builder: (context, state) => const NoAccessPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stock',
                builder: (context, state) => const StockPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shopping_list',
                builder: (context, state) => const ShoppingListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

/// 判定結果と今いる画面から、移動先を決める（移動しないなら null）
String? redirectFor(AccessStatus status, String location) {
  const splash = '/splash';
  const login = '/login';
  const noAccess = '/no_access';
  switch (status) {
    case AccessStatus.checking:
    case AccessStatus.error:
      // 権限エラー画面はサインアウト中も表示し続ける
      if (location == noAccess || location == splash) return null;
      return splash;
    case AccessStatus.signedOut:
      if (location == login || location == noAccess) return null;
      return login;
    case AccessStatus.denied:
      return location == noAccess ? null : noAccess;
    case AccessStatus.allowed:
      if (location == login || location == noAccess || location == splash) {
        return '/stock';
      }
      return null;
  }
}
