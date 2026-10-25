import 'item.dart';

/// 自分の並び順でアイテムを並べる。
///
/// [orderIds]（そのカテゴリのアイテム ID を表示順に並べたもの）に入っている
/// アイテムをその順に並べ、入っていないアイテムはその後ろに追加した順
/// （createdAt の古い順。保存中で null のものは最後）で並べる。
/// [orderIds] にあっても [items] にない ID は無視する。
List<Item> sortByMyOrder(Iterable<Item> items, List<String>? orderIds) {
  final rank = <String, int>{
    for (final (index, id) in (orderIds ?? const <String>[]).indexed)
      id: index,
  };
  final list = items.toList();
  list.sort((a, b) {
    final rankA = rank[a.id];
    final rankB = rank[b.id];
    if (rankA != null && rankB != null) return rankA.compareTo(rankB);
    if (rankA != null) return -1;
    if (rankB != null) return 1;

    final createdA = a.createdAt;
    final createdB = b.createdAt;
    if (createdA == null && createdB == null) return a.id.compareTo(b.id);
    if (createdA == null) return 1;
    if (createdB == null) return -1;
    final byCreated = createdA.compareTo(createdB);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  });
  return list;
}

/// [sorted] の [oldIndex] の位置のアイテムを [newIndex] に動かしたあとの、
/// アイテム ID の並びを返す（[newIndex] は動かすアイテムを取り除いた後の位置）。
List<String> moveItem(List<Item> sorted, int oldIndex, int newIndex) {
  final ids = [for (final item in sorted) item.id];
  final moved = ids.removeAt(oldIndex);
  ids.insert(newIndex.clamp(0, ids.length), moved);
  return ids;
}
