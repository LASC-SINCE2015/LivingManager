/// 許可されていないアカウントからの、利用の追加の依頼
class AccessRequest {
  const AccessRequest({
    required this.email,
    required this.displayName,
    required this.requestedAt,
  });

  /// 依頼したアカウントのメールアドレス（小文字）
  final String email;

  /// 依頼したアカウントの名前（Google アカウントの名前。ない場合は空）
  final String displayName;

  final DateTime? requestedAt;
}
