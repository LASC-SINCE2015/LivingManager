import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/auth/domain/member.dart';
import 'package:living_manager/features/items/domain/category.dart';
import 'package:living_manager/features/items/domain/item.dart';
import 'package:living_manager/features/items/domain/stock_status.dart';
import 'package:living_manager/features/shopping_list/domain/shopping_order.dart';

const _me = Member(uid: 'me', displayName: '自分');

Item _item(
  String id, {
  StockStatus status = StockStatus.empty,
  String categoryId = 'water',
  Purchase? purchase,
}) => Item(
  id: id,
  name: id,
  categoryId: categoryId,
  status: status,
  memo: '',
  purchase: purchase,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: null,
  updatedByUid: 'u',
  updatedByName: 'u',
);

Purchase _inCart(String uid) =>
    Purchase(state: PurchaseState.inCart, byUid: uid, byName: uid, at: null);

void main() {
  const categories = [
    Category(id: 'water', name: '水回り', order: 1),
    Category(id: 'kitchen', name: '台所', order: 2),
    Category(id: Category.otherId, name: 'その他', order: 9999),
  ];

  group('orderShoppingItems', () {
    test('「十分」は出さず、切れてる → 残りわずか、その中はカテゴリ順 → 自分の並び順', () {
      final ordered = orderShoppingItems(
        categories,
        [
          _item('low1', status: StockStatus.low),
          _item('ok', status: StockStatus.sufficient),
          _item('k1', categoryId: 'kitchen'),
          _item('w1'),
          _item('w2'),
        ],
        _me,
        const {
          'water': ['w2', 'w1'],
        },
      );
      expect([for (final i in ordered) i.id], ['w2', 'w1', 'k1', 'low1']);
    });

    test('ほかの人がカゴに入れたものはセクションの末尾', () {
      final ordered = orderShoppingItems(
        categories,
        [
          _item('others', purchase: _inCart('other')),
          _item('mine', purchase: _inCart('me')),
          _item('k1', categoryId: 'kitchen'),
        ],
        _me,
        const {},
      );
      expect([for (final i in ordered) i.id], ['mine', 'k1', 'others']);
    });
  });

  group('isSelectableForRequest', () {
    test('誰かがカゴに入れたものは LINE で頼むものに選べない', () {
      expect(isSelectableForRequest(_item('a')), isTrue);
      expect(
        isSelectableForRequest(
          _item(
            'b',
            purchase: const Purchase(
              state: PurchaseState.planned,
              byUid: 'other',
              byName: 'other',
              at: null,
            ),
          ),
        ),
        isTrue,
      );
      expect(
        isSelectableForRequest(_item('c', purchase: _inCart('me'))),
        isFalse,
      );
    });
  });
}
