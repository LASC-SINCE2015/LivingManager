import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/domain/member.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../items/data/items_repository.dart';
import '../../items/domain/category.dart';
import '../../items/domain/claim_result.dart';
import '../../items/domain/item.dart';
import '../../items/domain/item_order.dart';
import '../../items/domain/stock_status.dart';
import '../../items/presentation/item_actions.dart';
import '../../items/presentation/item_edit_sheet.dart';
import '../../items/presentation/items_providers.dart';
import '../../items/presentation/status_colors.dart';

/// 買い物リスト画面（タブ2）
class ShoppingListPage extends ConsumerWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final items = ref.watch(itemsProvider);
    final actor = ref.watch(actorProvider);
    final myOrder = ref.watch(myItemOrderProvider).value ?? const {};

    final myCartItems = [
      for (final item in items.value ?? const <Item>[])
        if (item.status.needsBuying &&
            item.purchase?.isInCart == true &&
            item.purchase?.byUid == actor?.uid)
          item,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('買い物リスト')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'アイテムを追加',
        onPressed: () =>
            showItemEditSheet(context, initialStatus: StockStatus.empty),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: myCartItems.isEmpty || actor == null
                ? null
                : () => _completePurchase(context, ref, myCartItems, actor),
            icon: const Icon(Icons.done_all),
            label: Text('購入完了（${myCartItems.length}件）'),
          ),
        ),
      ),
      body: switch ((categories.value, items.value, actor)) {
        _ when categories.hasError || items.hasError => const Center(
          child: Text('読み込めませんでした。通信状態を確認してください'),
        ),
        (
          final List<Category> cats,
          final List<Item> list,
          final Member me,
        ) =>
          _ShoppingList(
            categories: cats,
            items: list,
            me: me,
            myOrder: myOrder,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _completePurchase(
    BuildContext context,
    WidgetRef ref,
    List<Item> items,
    Member actor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(itemsRepositoryProvider);
    final result = await runWithErrorMessage(context, () async {
      await repository.completePurchase(items, actor);
      return true;
    });
    if (result != true) return;

    showUndoMessage(
      messenger,
      '${items.length}件を購入完了にしました',
      onUndo: () async {
        try {
          final reverted = await repository.revertPurchase(items, actor);
          if (reverted == items.length) return;
          showMessage(
            messenger,
            reverted == 0
                ? 'ほかの人が変更したため戻せませんでした'
                : 'ほかの人が変更したため、${items.length - reverted}件は戻せませんでした',
          );
        } catch (_) {
          showMessage(messenger, '元に戻せませんでした。通信状態を確認してください');
        }
      },
    );
  }
}

class _ShoppingList extends StatelessWidget {
  const _ShoppingList({
    required this.categories,
    required this.items,
    required this.me,
    required this.myOrder,
  });

  final List<Category> categories;
  final List<Item> items;
  final Member me;

  /// 自分の並び順（カテゴリ ID → アイテム ID の配列）
  final Map<String, List<String>> myOrder;

  /// ほかの人がカゴに入れたアイテムか（薄く表示して末尾に置く）
  bool _isOthersCart(Item item) =>
      item.purchase?.isInCart == true && item.purchase?.byUid != me.uid;

  @override
  Widget build(BuildContext context) {
    final targets = items.where((item) => item.status.needsBuying).toList();
    if (targets.isEmpty) {
      return const Center(child: Text('買う必要のあるものはありません 🎉'));
    }

    final orderOf = {for (final c in categories) c.id: c.order};
    final nameOf = {for (final c in categories) c.id: c.name};
    // カテゴリが見つからないアイテムは「その他」として扱う（在庫一覧と同じ）
    String categoryOf(Item item) => orderOf.containsKey(item.categoryId)
        ? item.categoryId
        : Category.otherId;

    // カテゴリごとに、自分の並び順での位置を求めておく
    final byCategory = <String, List<Item>>{};
    for (final item in targets) {
      byCategory.putIfAbsent(categoryOf(item), () => []).add(item);
    }
    final positionOf = <String, int>{
      for (final MapEntry(key: categoryId, value: list) in byCategory.entries)
        for (final (index, item)
            in sortByMyOrder(list, myOrder[categoryId]).indexed)
          item.id: index,
    };

    int compare(Item a, Item b) {
      final cart = (_isOthersCart(a) ? 1 : 0) - (_isOthersCart(b) ? 1 : 0);
      if (cart != 0) return cart;
      final order = (orderOf[categoryOf(a)] ?? 0).compareTo(
        orderOf[categoryOf(b)] ?? 0,
      );
      if (order != 0) return order;
      return positionOf[a.id]!.compareTo(positionOf[b.id]!);
    }

    final sections = [StockStatus.empty, StockStatus.low];
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        for (final status in sections)
          if (targets.any((item) => item.status == status)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Row(
                children: [
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: status.onLightColor,
                    ),
                  ),
                ],
              ),
            ),
            for (final item
                in targets.where((item) => item.status == status).toList()
                  ..sort(compare))
              _ShoppingTile(
                key: ValueKey(item.id),
                item: item,
                categoryName:
                    nameOf[item.categoryId] ?? nameOf[Category.otherId] ?? '',
                me: me,
              ),
          ],
      ],
    );
  }
}

/// 買い物リストのアイテム 1 件分
class _ShoppingTile extends ConsumerWidget {
  const _ShoppingTile({
    super.key,
    required this.item,
    required this.categoryName,
    required this.me,
  });

  final Item item;
  final String categoryName;
  final Member me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final purchase = item.purchase;
    final isMine = purchase?.byUid == me.uid;
    final othersCart = purchase != null && purchase.isInCart && !isMine;
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Opacity(
      opacity: othersCart ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: purchase?.isInCart ?? false,
                onChanged: othersCart
                    ? null
                    : (checked) => checked == true
                          ? _claim(context, ref, toCart: true)
                          : _uncheck(context, ref),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.titleMedium),
                      if (item.memo.isNotEmpty)
                        Text(item.memo, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '$categoryName・${item.updatedByName}・'
                        '${formatRelativeTime(item.updatedAt)} '
                        '${item.status.label}に変更',
                        style: mutedStyle,
                      ),
                      if (purchase != null)
                        Text(
                          purchaseLabel(purchase, myUid: me.uid) +
                              (purchase.isStale(DateTime.now())
                                  ? '（1日以上前）'
                                  : ''),
                          style: purchase.isStale(DateTime.now())
                              ? mutedStyle
                              : theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _actionButton(context, ref, purchase, isMine),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    WidgetRef ref,
    Purchase? purchase,
    bool isMine,
  ) {
    if (purchase == null) {
      return OutlinedButton(
        onPressed: () => _claim(context, ref, toCart: false),
        child: const Text('買います'),
      );
    }
    if (purchase.isInCart) return const SizedBox.shrink();
    if (isMine) {
      return TextButton(
        onPressed: () => _release(context, ref),
        child: const Text('やめる'),
      );
    }
    return TextButton(
      onPressed: () => _claim(context, ref, toCart: false),
      child: const Text('代わりに買う'),
    );
  }

  /// 担当者になる（[toCart] ならカゴ済みにする）。ほかの人の担当中なら確認する
  Future<void> _claim(
    BuildContext context,
    WidgetRef ref, {
    required bool toCart,
  }) async {
    final purchase = item.purchase;
    String? takeOverFromUid;
    if (purchase != null && purchase.byUid != me.uid) {
      final ok = await showConfirmDialog(
        context,
        message: '${purchase.byName}が買う予定です。代わりに買いますか？',
        okLabel: 'はい',
      );
      if (!ok || !context.mounted) return;
      takeOverFromUid = purchase.byUid;
    }
    final messenger = ScaffoldMessenger.of(context);
    final result = await runWithErrorMessage(
      context,
      () => ref
          .read(itemsRepositoryProvider)
          .claim(
            item.id,
            me,
            toCart: toCart,
            takeOverFromUid: takeOverFromUid,
          ),
    );
    switch (result) {
      case ClaimConflicted(:final holderName):
        showMessage(messenger, 'すでに$holderNameが担当しています');
      case ClaimItemGone():
        showMessage(messenger, 'このアイテムは買い物リストから外れました');
      case ClaimSucceeded() || null:
        break;
    }
  }

  Future<void> _release(BuildContext context, WidgetRef ref) =>
      runWithErrorMessage(
        context,
        () => ref.read(itemsRepositoryProvider).release(item.id, me),
      );

  Future<void> _uncheck(BuildContext context, WidgetRef ref) =>
      runWithErrorMessage(
        context,
        () => ref.read(itemsRepositoryProvider).uncheck(item.id, me),
      );
}
