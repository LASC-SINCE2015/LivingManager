import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/items/domain/barcode.dart';
import 'package:living_manager/features/items/domain/item.dart';
import 'package:living_manager/features/items/domain/stock_status.dart';

Item _item(String id, List<String> barcodes) => Item(
  id: id,
  name: id,
  categoryId: 'water',
  status: StockStatus.sufficient,
  memo: '',
  barcodes: barcodes,
  purchase: null,
  createdAt: null,
  updatedAt: null,
  updatedByUid: 'u',
  updatedByName: 'u',
);

void main() {
  group('normalizeBarcode', () {
    test('チェックデジットが合う JAN-13・JAN-8・ITF-14 はそのまま', () {
      expect(normalizeBarcode('4901234567894'), '4901234567894');
      expect(normalizeBarcode('49123456'), '49123456');
      expect(normalizeBarcode('14901234567891'), '14901234567891');
    });

    test('UPC-A（12 桁）は先頭に 0 を付けて 13 桁にする', () {
      expect(normalizeBarcode('036000291452'), '0036000291452');
    });

    test('空白・ハイフンは取り除く', () {
      expect(normalizeBarcode(' 4901234-567894 '), '4901234567894');
      expect(normalizeBarcode('4901234　567894'), '4901234567894');
    });

    test('チェックデジットが合わないもの・桁数違い・数字以外は使えない', () {
      expect(normalizeBarcode('4901234567890'), isNull);
      expect(normalizeBarcode('490123456789'), isNull);
      expect(normalizeBarcode('49012345678940'), isNull);
      expect(normalizeBarcode('49O1234567894'), isNull);
      expect(normalizeBarcode(''), isNull);
    });
  });

  group('findItemByBarcode', () {
    final items = [
      _item('a', ['4901234567894']),
      _item('b', ['49123456', '0036000291452']),
    ];

    test('バーコードが登録されているアイテムを返す', () {
      expect(findItemByBarcode(items, '0036000291452')?.id, 'b');
      expect(findItemByBarcode(items, '14901234567891'), isNull);
    });

    test('指定したアイテムは除く（編集中のアイテム自身は重複にしない）', () {
      expect(
        findItemByBarcode(items, '4901234567894', exceptItemId: 'a'),
        isNull,
      );
    });
  });
}
