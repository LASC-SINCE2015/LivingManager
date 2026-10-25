import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/users/domain/access_request.dart';
import 'package:living_manager/features/users/domain/allowed_user.dart';
import 'package:living_manager/features/users/domain/user_rules.dart';

void main() {
  AccessRequest request(String email, {String name = '', DateTime? at}) =>
      AccessRequest(email: email, displayName: name, requestedAt: at);

  group('validateUserMemo', () {
    test('空でもよい。50 文字まで', () {
      expect(validateUserMemo(''), isNull);
      expect(validateUserMemo('あ' * 50), isNull);
      expect(validateUserMemo('あ' * 51), isNotNull);
    });
  });

  group('initialMemoFor', () {
    test('依頼したアカウントの名前を 50 文字までで使う', () {
      expect(initialMemoFor(request('a@example.com', name: ' 山田 ')), '山田');
      expect(initialMemoFor(request('a@example.com', name: 'あ' * 60)), 'あ' * 50);
    });
  });

  group('sortRequestsOldestFirst', () {
    test('古い順。日時が未確定のものは最後', () {
      final sorted = sortRequestsOldestFirst([
        request('new@example.com', at: DateTime(2026, 10, 2)),
        request('pending@example.com'),
        request('old@example.com', at: DateTime(2026, 10, 1)),
      ]);
      expect(sorted.map((r) => r.email), [
        'old@example.com',
        'new@example.com',
        'pending@example.com',
      ]);
    });
  });

  group('sortAllowedUsers', () {
    test('開発者が先で、メールアドレス順', () {
      final sorted = sortAllowedUsers(const [
        AllowedUser(email: 'b@example.com', memo: '', admin: false),
        AllowedUser(email: 'z@example.com', memo: '', admin: true),
        AllowedUser(email: 'a@example.com', memo: '', admin: false),
      ]);
      expect(sorted.map((u) => u.email), [
        'z@example.com',
        'a@example.com',
        'b@example.com',
      ]);
    });
  });
}
