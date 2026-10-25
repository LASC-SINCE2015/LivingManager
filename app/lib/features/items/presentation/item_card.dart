import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/relative_time.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/item.dart';
import 'item_actions.dart';
import 'item_edit_sheet.dart';
import 'status_colors.dart';
import 'status_selector.dart';

enum _ItemMenu { edit, delete }

/// 在庫一覧のアイテム 1 件分のカード（1 行に詰めて表示する）
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
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左端の色帯で、ステータスをひと目でわかるようにする
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              color: item.status.color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.memo.isNotEmpty)
                      Text(
                        item.memo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    Text(
                      '${item.updatedByName}・${formatRelativeTime(item.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle?.copyWith(fontSize: 11),
                    ),
                    if (purchase != null)
                      Text(
                        purchaseLabel(purchase, myUid: myUid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: StatusIconSelector(
                selected: item.status,
                onChanged: (next) => changeItemStatus(context, ref, item, next),
              ),
            ),
            Center(
              child: PopupMenuButton<_ItemMenu>(
                tooltip: 'メニュー',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (menu) => switch (menu) {
                  _ItemMenu.edit => showItemEditSheet(context, item: item),
                  _ItemMenu.delete => deleteItemWithConfirm(context, ref, item),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _ItemMenu.edit, child: Text('編集')),
                  PopupMenuItem(value: _ItemMenu.delete, child: Text('削除')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
