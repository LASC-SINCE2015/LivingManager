import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/history_repository.dart';
import '../domain/purchase_record.dart';

/// ログイン中の uid（サインアウトしたら購読をやめるために使う）
final _uidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.uid)),
);

/// すべての購入履歴（新しい順）。購入履歴の画面を開いている間だけ購読する
final allHistoryProvider = StreamProvider.autoDispose<List<PurchaseRecord>>((
  ref,
) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(historyRepositoryProvider).watchAll();
});

/// 1 つのアイテムの購入履歴（新しい順）。編集シートを開いている間だけ購読する
final itemHistoryProvider = StreamProvider.autoDispose
    .family<List<PurchaseRecord>, String>((ref, itemId) {
      if (ref.watch(_uidProvider) == null) return Stream.value(const []);
      return ref.watch(historyRepositoryProvider).watchForItem(itemId);
    });
