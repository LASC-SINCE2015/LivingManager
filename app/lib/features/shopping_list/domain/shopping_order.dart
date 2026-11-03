import '../../auth/domain/member.dart';
import '../../items/domain/category.dart';
import '../../items/domain/item.dart';
import '../../items/domain/item_order.dart';
import '../../items/domain/stock_status.dart';

/// LINE で頼むものとして選べるか（誰かがカゴに入れたものは、もう買っているので選べない）
bool isSelectableForRequest(Item item) => item.purchase?.isInCart != true;

/// 買い物リストに出すアイテムを、表示する順に並べる。
///
/// 「切れてる」→「残りわずか」の順。それぞれの中は、ほかの人がカゴに入れたものを
/// 末尾にし、カテゴリの順 → 同じカテゴリ内は自分の並び順で並べる。
List<Item> orderShoppingItems(
  List<Category> categories,
  List<Item> items,
  Member me,
  Map<String, List<String>> myOrder,
) {
  final targets = items.where((item) => item.status.needsBuying).toList();
  final orderOf = {for (final c in categories) c.id: c.order};
  // カテゴリが見つからないアイテムは「その他」として扱う（在庫一覧と同じ）
  String categoryOf(Item item) =>
      orderOf.containsKey(item.categoryId) ? item.categoryId : Category.otherId;
  bool isOthersCart(Item item) =>
      item.purchase?.isInCart == true && item.purchase?.byUid != me.uid;

  // カテゴリごとに、自分の並び順での位置を求めておく
  final byCategory = <String, List<Item>>{};
  for (final item in targets) {
    byCategory.putIfAbsent(categoryOf(item), () => []).add(item);
  }
  final positionOf = <String, int>{
    for (final MapEntry(key: categoryId, value: list) in byCategory.entries)
      for (final (index, item) in sortByMyOrder(
        list,
        myOrder[categoryId],
      ).indexed)
        item.id: index,
  };

  int compare(Item a, Item b) {
    final section = _sectionIndex(a.status) - _sectionIndex(b.status);
    if (section != 0) return section;
    final cart = (isOthersCart(a) ? 1 : 0) - (isOthersCart(b) ? 1 : 0);
    if (cart != 0) return cart;
    final order = (orderOf[categoryOf(a)] ?? 0).compareTo(
      orderOf[categoryOf(b)] ?? 0,
    );
    if (order != 0) return order;
    return positionOf[a.id]!.compareTo(positionOf[b.id]!);
  }

  return targets..sort(compare);
}

/// 買い物リストのセクション（上から「切れてる」「残りわずか」）
const shoppingSections = [StockStatus.empty, StockStatus.low];

int _sectionIndex(StockStatus status) => shoppingSections.indexOf(status);
