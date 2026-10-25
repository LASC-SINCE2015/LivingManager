import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/items/domain/item.dart';
import 'package:living_manager/features/items/domain/item_order.dart';
import 'package:living_manager/features/items/domain/stock_status.dart';

Item _item(String id, {DateTime? createdAt}) => Item(
  id: id,
  name: id,
  categoryId: 'water',
  status: StockStatus.sufficient,
  memo: '',
  purchase: null,
  createdAt: createdAt,
  updatedAt: null,
  updatedByUid: 'u',
  updatedByName: 'u',
);

List<String> _ids(List<Item> items) => [for (final item in items) item.id];

void main() {
  final day1 = DateTime(2026, 10, 1);
  final day2 = DateTime(2026, 10, 2);
  final day3 = DateTime(2026, 10, 3);

  group('sortByMyOrder', () {
    test('並び順に入っているアイテムは、その順に並ぶ', () {
      final items = [_item('a'), _item('b'), _item('c')];
      expect(_ids(sortByMyOrder(items, ['c', 'a', 'b'])), ['c', 'a', 'b']);
    });

    test('並び順がなければ、追加した順（古い順）に並ぶ', () {
      final items = [
        _item('a', createdAt: day3),
        _item('b', createdAt: day1),
        _item('c', createdAt: day2),
      ];
      expect(_ids(sortByMyOrder(items, null)), ['b', 'c', 'a']);
    });

    test('並び順に入っていないアイテムは末尾に、追加した順で並ぶ', () {
      final items = [
        _item('a', createdAt: day1),
        _item('new2', createdAt: day3),
        _item('b', createdAt: day2),
        _item('new1', createdAt: day2),
      ];
      expect(_ids(sortByMyOrder(items, ['b', 'a'])), [
        'b',
        'a',
        'new1',
        'new2',
      ]);
    });

    test('保存中（追加日時が null）のアイテムは一番最後', () {
      final items = [_item('saving'), _item('old', createdAt: day1)];
      expect(_ids(sortByMyOrder(items, const [])), ['old', 'saving']);
    });

    test('存在しないアイテムの ID は無視する', () {
      final items = [_item('a'), _item('b')];
      expect(_ids(sortByMyOrder(items, ['deleted', 'b', 'a'])), ['b', 'a']);
    });
  });

  group('moveItem', () {
    final sorted = [_item('a'), _item('b'), _item('c')];

    test('下に動かす', () {
      expect(moveItem(sorted, 0, 2), ['b', 'c', 'a']);
    });

    test('上に動かす', () {
      expect(moveItem(sorted, 2, 0), ['c', 'a', 'b']);
    });
  });
}
