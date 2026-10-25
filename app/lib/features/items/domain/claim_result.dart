/// 担当宣言・カゴ済みチェックの結果
sealed class ClaimResult {
  const ClaimResult();
}

/// 担当者になれた
class ClaimSucceeded extends ClaimResult {
  const ClaimSucceeded();
}

/// ほかの人が先に担当していた（上書きしていない）
class ClaimConflicted extends ClaimResult {
  const ClaimConflicted(this.holderName);

  /// 先に担当していた人の表示名
  final String holderName;
}

/// アイテムが削除された、または買い物リストから外れていた
class ClaimItemGone extends ClaimResult {
  const ClaimItemGone();
}
