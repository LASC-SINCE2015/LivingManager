/// 利用を許可されたアカウント（許可リストの 1 件）
class AllowedUser {
  const AllowedUser({
    required this.email,
    required this.memo,
    required this.admin,
  });

  /// メールアドレス（小文字）
  final String email;

  /// 誰のアカウントかのメモ（例: 「父」）
  final String memo;

  /// 開発者（管理者）か
  final bool admin;
}
