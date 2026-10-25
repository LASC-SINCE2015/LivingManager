import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/relative_time.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/item.dart';
import 'item_actions.dart';
import 'item_edit_sheet.dart';
import 'status_selector.dart';

enum _ItemMenu { edit, delete }

/// 在庫一覧のアイテム 1 件分のカード
class ItemCard extends ConsumerWidget {
  const ItemCard({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myUid = ref.watch(actorProvider)?.uid ?? '';
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final purchase = item.purchase;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name, style: theme.textTheme.titleMedium),
                ),
                PopupMenuButton<_ItemMenu>(
                  tooltip: 'メニュー',
                  onSelected: (menu) => switch (menu) {
                    _ItemMenu.edit => showItemEditSheet(context, item: item),
                    _ItemMenu.delete => deleteItemWithConfirm(
                      context,
                      ref,
                      item,
                    ),
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: _ItemMenu.edit, child: Text('編集')),
                    PopupMenuItem(value: _ItemMenu.delete, child: Text('削除')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.memo.isNotEmpty)
                    Text(
                      item.memo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                  const SizedBox(height: 8),
                  StatusSelector(
                    selected: item.status,
                    onChanged: (next) =>
                        changeItemStatus(context, ref, item, next),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.updatedByName}・${formatRelativeTime(item.updatedAt)}',
                    style: mutedStyle,
                  ),
                  if (purchase != null)
                    Text(
                      purchaseLabel(purchase, myUid: myUid),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
