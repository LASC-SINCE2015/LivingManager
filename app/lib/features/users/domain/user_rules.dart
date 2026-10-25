import 'access_request.dart';
import 'allowed_user.dart';

/// 許可リストのメモの最大文字数
const userMemoMaxLength = 50;

/// 依頼に記録する名前の最大文字数
const requestNameMaxLength = 50;

/// メモの入力チェック（問題なければ null）
String? validateUserMemo(String value) {
  if (value.length > userMemoMaxLength) {
    return '$userMemoMaxLength文字以内で入力してください';
  }
  return null;
}

/// 承認するときのメモの初期値（依頼したアカウントの名前）
String initialMemoFor(AccessRequest request) {
  final name = request.displayName.trim();
  return name.length > userMemoMaxLength
      ? name.substring(0, userMemoMaxLength)
      : name;
}

/// 依頼を古い順に並べる（日時が未確定のものは最後）
List<AccessRequest> sortRequestsOldestFirst(Iterable<AccessRequest> requests) {
  final list = requests.toList();
  list.sort((a, b) {
    final at = a.requestedAt;
    final bt = b.requestedAt;
    if (at == null && bt == null) return a.email.compareTo(b.email);
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  });
  return list;
}

/// 許可済みのアカウントを、開発者を先に、メールアドレス順に並べる
List<AllowedUser> sortAllowedUsers(Iterable<AllowedUser> users) {
  final list = users.toList();
  list.sort((a, b) {
    if (a.admin != b.admin) return a.admin ? -1 : 1;
    return a.email.compareTo(b.email);
  });
  return list;
}
