import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/items/presentation/items_page.dart';

/// 画面遷移の定義。画面を増やすときはここに GoRoute を追加する。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ItemsPage(),
      ),
    ],
  );
});
