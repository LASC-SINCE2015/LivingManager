import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/core/router/redirect.dart';
import 'package:living_manager/features/auth/domain/access_status.dart';

void main() {
  String? go(AccessStatus status, String location) =>
      redirectFor(status, Uri.parse(location));

  group('redirectFor', () {
    test('判定中は判定中の画面へ。開こうとした画面を from で引き継ぐ', () {
      expect(go(AccessStatus.checking, '/shopping_list'), '/splash?from=%2Fshopping_list');
      expect(go(AccessStatus.checking, '/splash?from=%2Fsettings'), isNull);
    });

    test('判定中・エラーでも権限エラー画面には留まる', () {
      expect(go(AccessStatus.checking, '/no_access'), isNull);
      expect(go(AccessStatus.error, '/no_access'), isNull);
    });

    test('未ログインならログイン画面へ。from を引き継ぐ', () {
      expect(go(AccessStatus.signedOut, '/settings/categories'), '/login?from=%2Fsettings%2Fcategories');
      expect(go(AccessStatus.signedOut, '/splash?from=%2Fstock'), '/login?from=%2Fstock');
      expect(go(AccessStatus.signedOut, '/login?from=%2Fstock'), isNull);
    });

    test('戻ってよい画面以外は from に入れない', () {
      expect(go(AccessStatus.signedOut, '/unknown'), '/login');
      expect(go(AccessStatus.allowed, '/login?from=https%3A%2F%2Fexample.com'), '/stock');
    });

    test('利用できるようになったら from の画面へ戻る', () {
      expect(go(AccessStatus.allowed, '/splash?from=%2Fshopping_list'), '/shopping_list');
      expect(go(AccessStatus.allowed, '/login'), '/stock');
      expect(go(AccessStatus.allowed, '/settings'), isNull);
    });

    test('改善意見の画面にもログイン後に戻れる', () {
      expect(go(AccessStatus.signedOut, '/feedback'), '/login?from=%2Ffeedback');
      expect(go(AccessStatus.allowed, '/login?from=%2Ffeedback'), '/feedback');
      expect(go(AccessStatus.allowed, '/splash?from=%2Fsettings%2Ffeedback'), '/settings/feedback');
    });

    test('ユーザー管理の画面にもログイン後に戻れる', () {
      expect(go(AccessStatus.signedOut, '/users'), '/login?from=%2Fusers');
      expect(go(AccessStatus.allowed, '/splash?from=%2Fusers'), '/users');
    });

    test('許可されていなければ権限エラー画面へ', () {
      expect(go(AccessStatus.denied, '/splash?from=%2Fstock'), '/no_access');
      expect(go(AccessStatus.denied, '/no_access'), isNull);
    });
  });
}
