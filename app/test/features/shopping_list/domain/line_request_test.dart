import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/items/domain/item.dart';
import 'package:living_manager/features/items/domain/stock_status.dart';
import 'package:living_manager/features/shopping_list/domain/line_request.dart';

Item _item(String name, {String memo = ''}) => Item(
  id: name,
  name: name,
  categoryId: 'water',
  status: StockStatus.empty,
  memo: memo,
  purchase: null,
  createdAt: null,
  updatedAt: null,
  updatedByUid: 'u',
  updatedByName: 'u',
);

void main() {
  group('buildLineRequestText', () {
    test('頼むアイテムを 1 行ずつ並べ、メモは（ ）で添える', () {
      final text = buildLineRequestText([
        _item('トイレットペーパー', memo: '12ロール'),
        _item('食器用洗剤'),
      ]);
      expect(text, '買い物をお願いします。\n・トイレットペーパー（12ロール）\n・食器用洗剤');
    });

    test('メモの改行は空白にし、前後の空白は取り除く', () {
      final text = buildLineRequestText([
        _item('洗剤', memo: ' 詰め替え用\n 大きいほう '),
        _item('牛乳', memo: '  '),
      ]);
      expect(text, '買い物をお願いします。\n・洗剤（詰め替え用 大きいほう）\n・牛乳');
    });
  });

  group('lineShareUri', () {
    test('LINE の送信先選択の URL に、文面を %20 の形でエンコードして入れる', () {
      final uri = lineShareUri('買い物を お願い\n・牛乳');
      expect(uri.origin, 'https://line.me');
      expect(uri.path, '/R/share');
      expect(uri.toString(), isNot(contains('+')));
      expect(uri.queryParameters['text'], '買い物を お願い\n・牛乳');
    });
  });
}
