/// 家族メンバー（users コレクションの 1 件）
///
/// 更新者・担当者として記録するときにも使う。
class Member {
  const Member({required this.uid, required this.displayName});

  final String uid;

  /// 表示名（例: 「お父さん」）
  final String displayName;
}
