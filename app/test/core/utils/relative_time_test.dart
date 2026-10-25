import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/core/utils/relative_time.dart';

void main() {
  group('formatRelativeTime', () {
    final now = DateTime(2026, 10, 25, 12, 0);

    test('保存中（null）は「たった今」', () {
      expect(formatRelativeTime(null, now: now), 'たった今');
    });

    test('1分未満は「たった今」', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'たった今',
      );
    });

    test('1時間未満は「N分前」', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5分前',
      );
    });

    test('24時間未満は「N時間前」', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3時間前',
      );
    });

    test('24時間以上で前日なら「昨日」', () {
      expect(formatRelativeTime(DateTime(2026, 10, 24, 8, 0), now: now), '昨日');
    });

    test('それより前の今年は「M月D日」', () {
      expect(formatRelativeTime(DateTime(2026, 9, 1), now: now), '9月1日');
    });

    test('前年以前は「YYYY年M月D日」', () {
      expect(
        formatRelativeTime(DateTime(2025, 12, 31), now: now),
        '2025年12月31日',
      );
    });
  });
}
