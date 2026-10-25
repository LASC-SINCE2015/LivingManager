import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/items_repository.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';

/// 担当・カゴ済みの状態を表す文（例: 「🛒 お父さんが買う予定」）
String purchaseLabel(Purchase purchase, {required String myUid}) {
  final who = purchase.byUid == myUid ? 'あなた' : purchase.byName;
  return purchase.isInCart
      ? (purchase.byUid == myUid ? '✅ カゴに入れました' : '✅ $whoがカゴに入れました')
      : '🛒 $whoが買う予定';
}

/// ステータスを変更する。
///
/// 「十分」にするとき、ほかの人が担当していたら確認してから変更する。
Future<void> changeItemStatus(
  BuildContext context,
  WidgetRef ref,
  Item item,
  StockStatus next,
) async {
  if (next == item.status) return;
  final actor = ref.read(actorProvider);
  if (actor == null) return;

  final purchase = item.purchase;
  if (!next.needsBuying && purchase != null && purchase.byUid != actor.uid) {
    final doing = purchase.isInCart ? 'カゴに入れています' : '買う予定です';
    final ok = await showConfirmDialog(
      context,
      message: '${purchase.byName}が$doing。「${next.label}」にしますか？',
      okLabel: '${next.label}にする',
    );
    if (!ok || !context.mounted) return;
  }

  await runWithErrorMessage(
    context,
    () => ref
        .read(itemsRepositoryProvider)
        .changeStatus(item.id, next, actor),
  );
}

/// 確認してからアイテムを削除する
Future<void> deleteItemWithConfirm(
  BuildContext context,
  WidgetRef ref,
  Item item,
) async {
  final ok = await showConfirmDialog(
    context,
    message: '『${item.name}』を削除しますか？',
    okLabel: '削除',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await runWithErrorMessage(
    context,
    () => ref.read(itemsRepositoryProvider).deleteItem(item.id),
  );
}
