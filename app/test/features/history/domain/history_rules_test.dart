import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/history/domain/history_rules.dart';
import 'package:living_manager/features/history/domain/purchase_record.dart';

PurchaseRecord _record(String id, DateTime? at) => PurchaseRecord(
  id: id,
  itemId: 'item',
  itemName: 'トイレットペーパー',
  byUid: 'u',
  byName: 'お母さん',
  purchasedAt: at,
);

void main() {
  group('expiryCutoff', () {
    test('残す期間（1 年）より 1 日余分に前の日時になる', () {
      final now = DateTime(2026, 11, 1, 9);
      expect(expiryCutoff(now), now.subtract(const Duration(days: 366)));
    });
  });

  group('sortRecordsNewestFirst', () {
    test('新しい順。日時が未確定のものは一番上', () {
      final sorted = sortRecordsNewestFirst([
        _record('old', DateTime(2026, 1, 1)),
        _record('saving', null),
        _record('new', DateTime(2026, 10, 1)),
      ]);
      expect([for (final r in sorted) r.id], ['saving', 'new', 'old']);
    });
  });

  group('formatPurchaseDate', () {
    test('「YYYY年M月D日（曜日）」の形', () {
      expect(formatPurchaseDate(DateTime(2026, 11, 1, 9)), '2026年11月1日（日）');
      expect(formatPurchaseDate(DateTime(2026, 10, 26)), '2026年10月26日（月）');
    });

    test('保存中（null）は「たった今」', () {
      expect(formatPurchaseDate(null), 'たった今');
    });
  });
}
