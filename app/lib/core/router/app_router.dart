import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/access_status.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/no_access_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/feedback/presentation/feedback_list_page.dart';
import '../../features/feedback/presentation/send_feedback_page.dart';
import '../../features/items/presentation/stock_page.dart';
import '../../features/settings/presentation/categories_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shopping_list/presentation/shopping_list_page.dart';
import '../../features/users/presentation/users_page.dart';
import 'home_shell.dart';
import 'redirect.dart';

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
    initialLocation: stockPath,
    refreshListenable: status,
    redirect: (context, state) => redirectFor(status.value, state.uri),
    routes: [
      GoRoute(path: splashPath, builder: (context, state) => const SplashPage()),
      GoRoute(path: loginPath, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: noAccessPath,
        builder: (context, state) => const NoAccessPage(),
      ),
      // 改善意見の一覧（開発者用）は下部のタブを出さない独立したページ
      GoRoute(
        path: feedbackListPath,
        builder: (context, state) => const FeedbackListPage(),
      ),
      // ユーザー管理（開発者用）も下部のタブを出さない独立したページ
      GoRoute(path: usersPath, builder: (context, state) => const UsersPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: stockPath,
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
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesPage(),
                  ),
                  GoRoute(
                    path: 'feedback',
                    builder: (context, state) => const SendFeedbackPage(),
                  ),
                ],
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
