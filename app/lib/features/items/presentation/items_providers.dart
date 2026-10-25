import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/member_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/items_repository.dart';
import '../domain/category.dart';
import '../domain/item.dart';

/// ログイン中の uid（サインアウトしたら購読をやめるために使う）
final _uidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.uid)),
);

/// カテゴリ（表示順）
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(itemsRepositoryProvider).watchCategories();
});

/// すべてのアイテム（並び順は画面側で決める）
final itemsProvider = StreamProvider<List<Item>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(itemsRepositoryProvider).watchItems();
});

/// 買い物リストに出ている件数
final shoppingCountProvider = Provider<int>((ref) {
  final items = ref.watch(itemsProvider).value ?? const [];
  return items.where((item) => item.status.needsBuying).length;
});

/// 自分の並び順（カテゴリ ID → アイテム ID の配列）
final myItemOrderProvider = StreamProvider<Map<String, List<String>>>((ref) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(memberRepositoryProvider).watchItemOrder(uid);
});
