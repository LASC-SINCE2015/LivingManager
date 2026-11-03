import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/domain/member.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../items/data/items_repository.dart';
import '../../items/domain/category.dart';
import '../../items/domain/claim_result.dart';
import '../../items/domain/item.dart';
import '../../items/domain/stock_status.dart';
import '../../items/presentation/item_actions.dart';
import '../../items/presentation/item_edit_sheet.dart';
import '../../items/presentation/items_providers.dart';
import '../../items/presentation/status_colors.dart';
import '../domain/line_request.dart';
import '../domain/shopping_order.dart';

/// 買い物リスト画面（タブ2）
class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  /// LINE で頼むものを選んでいる（選択モード）か
  bool _selecting = false;

  /// 選択モードで選んでいるアイテムの ID
  final Set<String> _selected = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ほかのタブに切り替えたら（このタブが非表示になったら）通常の表示に戻す
    if (_selecting && !TickerMode.valuesOf(context).enabled) {
      _selecting = false;
      _selected.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final items = ref.watch(itemsProvider);
    final actor = ref.watch(actorProvider);
    final myOrder = ref.watch(myItemOrderProvider).value ?? const {};

    final ordered = switch ((categories.value, items.value, actor)) {
      (final List<Category> cats, final List<Item> list, final Member me) =>
        orderShoppingItems(cats, list, me, myOrder),
      _ => null,
    };
    final myCartItems = [
      for (final item in ordered ?? const <Item>[])
        if (item.purchase?.isInCart == true &&
            item.purchase?.byUid == actor?.uid)
          item,
    ];
    // 選んだあとに買い物リストから外れたもの・カゴに入ったものは除く
    final selectedItems = [
      for (final item in ordered ?? const <Item>[])
        if (_selected.contains(item.id) && isSelectableForRequest(item)) item,
    ];
    final selectable = (ordered ?? const <Item>[])
        .where(isSelectableForRequest)
        .toList();

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: 'やめる',
                icon: const Icon(Icons.close),
                onPressed: _endSelecting,
              ),
              title: Text('頼むものを選ぶ（${selectedItems.length}件）'),
              actions: [
                TextButton(
                  onPressed: selectable.isEmpty
                      ? null
                      : () => setState(() {
                          if (selectedItems.length == selectable.length) {
                            _selected.clear();
                          } else {
                            _selected.addAll(selectable.map((item) => item.id));
                          }
                        }),
                  child: Text(
                    selectable.isNotEmpty &&
                            selectedItems.length == selectable.length
                        ? 'すべて解除'
                        : 'すべて選択',
                  ),
                ),
              ],
            )
          : AppBar(
              title: const Text('買い物リスト'),
              actions: [
                IconButton(
                  tooltip: 'LINEで頼む',
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  onPressed: selectable.isEmpty
                      ? null
                      : () => setState(() => _selecting = true),
                ),
              ],
            ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              tooltip: 'アイテムを追加',
              onPressed: () =>
                  showItemEditSheet(context, initialStatus: StockStatus.empty),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _selecting
              ? FilledButton.icon(
                  onPressed: selectedItems.isEmpty
                      ? null
                      : () => _sendToLine(selectedItems),
                  icon: const Icon(Icons.send),
                  label: Text('LINEで送る（${selectedItems.length}件）'),
                )
              : FilledButton.icon(
                  onPressed: myCartItems.isEmpty || actor == null
                      ? null
                      : () => _completePurchase(myCartItems, actor),
                  icon: const Icon(Icons.done_all),
                  label: Text('購入完了（${myCartItems.length}件）'),
                ),
        ),
      ),
      body: switch ((categories.value, ordered, actor)) {
        _ when categories.hasError || items.hasError => const Center(
          child: Text('読み込めませんでした。通信状態を確認してください'),
        ),
        (final List<Category> cats, final List<Item> list, final Member me) =>
          _ShoppingList(
            categories: cats,
            ordered: list,
            me: me,
            selecting: _selecting,
            selected: _selected,
            onSelectChanged: (item, selected) => setState(
              () =>
                  selected ? _selected.add(item.id) : _selected.remove(item.id),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _endSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  /// 選んだアイテムを頼む文面で、LINE の送信先選択を開く
  Future<void> _sendToLine(List<Item> items) async {
    final messenger = ScaffoldMessenger.of(context);
    // ボタンを押した操作の中で開く必要がある（ブラウザがポップアップを止めないように）ので、
    // ここより前で await しない
    final opened = launchUrl(
      lineShareUri(buildLineRequestText(items)),
      webOnlyWindowName: '_blank',
    );
    _endSelecting();
    try {
      if (await opened) return;
    } catch (_) {
      // 下でまとめて知らせる
    }
    showMessage(messenger, 'LINEを開けませんでした');
  }

  Future<void> _completePurchase(List<Item> items, Member actor) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(itemsRepositoryProvider);
    final recordIds = await runWithErrorMessage(
      context,
      () => repository.completePurchase(items, actor),
    );
    if (recordIds == null) return;

    showUndoMessage(
      messenger,
      '${items.length}件を購入完了にしました',
      onUndo: () async {
        try {
          final reverted = await repository.revertPurchase(
            items,
            actor,
            recordIds: recordIds,
          );
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
    required this.ordered,
    required this.me,
    required this.selecting,
    required this.selected,
    required this.onSelectChanged,
  });

  final List<Category> categories;

  /// 表示する順に並べたアイテム（[orderShoppingItems]）
  final List<Item> ordered;
  final Member me;

  /// LINE で頼むものを選んでいるか
  final bool selecting;
  final Set<String> selected;
  final void Function(Item item, bool selected) onSelectChanged;

  @override
  Widget build(BuildContext context) {
    if (ordered.isEmpty) {
      return const Center(child: Text('買う必要のあるものはありません 🎉'));
    }

    final nameOf = {for (final c in categories) c.id: c.name};
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        for (final status in shoppingSections)
          if (ordered.any((item) => item.status == status)) ...[
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
            for (final item in ordered.where((item) => item.status == status))
              _ShoppingTile(
                key: ValueKey(item.id),
                item: item,
                categoryName:
                    nameOf[item.categoryId] ?? nameOf[Category.otherId] ?? '',
                me: me,
                selecting: selecting,
                selected: selected.contains(item.id),
                onSelectChanged: (value) => onSelectChanged(item, value),
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
    required this.selecting,
    required this.selected,
    required this.onSelectChanged,
  });

  final Item item;
  final String categoryName;
  final Member me;

  /// LINE で頼むものを選んでいるか（チェックボックスは選択に使い、担当の操作は出さない）
  final bool selecting;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final purchase = item.purchase;
    final isMine = purchase?.byUid == me.uid;
    final othersCart = purchase != null && purchase.isInCart && !isMine;
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final selectable = isSelectableForRequest(item);
    return Opacity(
      opacity: othersCart || (selecting && !selectable) ? 0.5 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selecting && selectable
              ? () => onSelectChanged(!selected)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting)
                  Checkbox(
                    value: selected,
                    onChanged: selectable
                        ? (checked) => onSelectChanged(checked == true)
                        : null,
                  )
                else
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
                if (!selecting) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _actionButton(context, ref, purchase, isMine),
                  ),
                ],
              ],
            ),
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
          .claim(item.id, me, toCart: toCart, takeOverFromUid: takeOverFromUid),
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
