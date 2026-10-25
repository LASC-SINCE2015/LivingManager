import '../../features/auth/domain/access_status.dart';

const splashPath = '/splash';
const loginPath = '/login';
const noAccessPath = '/no_access';
const stockPath = '/stock';

/// ログイン後に戻ってよい画面（これ以外は在庫一覧へ）
const returnablePaths = {
  '/stock',
  '/shopping_list',
  '/settings',
  '/settings/categories',
  '/settings/feedback',
  feedbackListPath,
};

const feedbackListPath = '/feedback';

/// 判定結果と今の URL から、移動先を決める（移動しないなら null）。
///
/// ログイン画面・判定中の画面へ送るときは、最初に開こうとした画面を
/// クエリ `from` に入れて引き継ぎ、利用できると分かった時点でそこへ戻す。
String? redirectFor(AccessStatus status, Uri uri) {
  final path = uri.path;
  switch (status) {
    case AccessStatus.checking:
    case AccessStatus.error:
      // 権限エラー画面はサインアウト中も表示し続ける
      if (path == noAccessPath || path == splashPath) return null;
      return _withFrom(splashPath, _returnPath(uri));
    case AccessStatus.signedOut:
      if (path == loginPath || path == noAccessPath) return null;
      return _withFrom(loginPath, _returnPath(uri));
    case AccessStatus.denied:
      return path == noAccessPath ? null : noAccessPath;
    case AccessStatus.allowed:
      if (path == loginPath || path == noAccessPath || path == splashPath) {
        return _returnPath(uri) ?? stockPath;
      }
      return null;
  }
}

/// 戻り先。今いる画面が戻ってよい画面ならそれ、そうでなければ `from` を引き継ぐ
String? _returnPath(Uri uri) {
  if (returnablePaths.contains(uri.path)) return uri.path;
  final from = uri.queryParameters['from'];
  return returnablePaths.contains(from) ? from : null;
}

String _withFrom(String path, String? from) =>
    from == null ? path : Uri(path: path, queryParameters: {'from': from}).toString();
