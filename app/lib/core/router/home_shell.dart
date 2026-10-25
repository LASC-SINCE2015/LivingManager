import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/items/presentation/items_providers.dart';

/// メイン画面の枠（画面下部のタブ）
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(shoppingCountProvider);
    Widget cartIcon(IconData icon) => Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(icon),
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '在庫一覧',
          ),
          NavigationDestination(
            icon: cartIcon(Icons.shopping_cart_outlined),
            selectedIcon: cartIcon(Icons.shopping_cart),
            label: '買い物リスト',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
