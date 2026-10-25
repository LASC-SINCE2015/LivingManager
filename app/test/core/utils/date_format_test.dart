import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/core/utils/date_format.dart';

void main() {
  group('formatDateTime', () {
    test('YYYY/MM/DD HH:mm の形（ゼロ埋め）', () {
      expect(formatDateTime(DateTime(2026, 3, 5, 9, 7)), '2026/03/05 09:07');
    });

    test('保存中（null）は「送信中」', () {
      expect(formatDateTime(null), '送信中');
    });
  });
}
