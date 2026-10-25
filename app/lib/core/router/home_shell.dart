import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/items/presentation/connectivity_provider.dart';
import '../../features/items/presentation/items_providers.dart';

/// メイン画面の枠（タブ・オフライン表示）。
///
/// 画面幅が [wideBreakpoint] 以上なら左のナビゲーション、未満なら画面下部のタブ。
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  static const wideBreakpoint = 768.0;

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(shoppingCountProvider);
    final offline = ref.watch(isOfflineProvider);
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;

    Widget cartIcon(IconData icon) => Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(icon),
    );

    final content = Column(
      children: [
        if (offline) const _OfflineBanner(),
        Expanded(
          // バナーが上部の余白（ステータスバー分）を使うので、中の画面からは外す
          child: offline
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: navigationShell,
                )
              : navigationShell,
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('在庫一覧'),
                ),
                NavigationRailDestination(
                  icon: cartIcon(Icons.shopping_cart_outlined),
                  selectedIcon: cartIcon(Icons.shopping_cart),
                  label: const Text('買い物リスト'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('設定'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
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

/// 画面上部の「オフラインです」表示
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 18, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'オフラインです。変更は接続が戻ると反映されます',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
