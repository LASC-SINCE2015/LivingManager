/// 購入完了の記録（purchaseHistory コレクションの 1 件）
class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.byUid,
    required this.byName,
    required this.purchasedAt,
  });

  final String id;

  /// 買ったアイテムのドキュメント ID（アイテムを削除しても記録は残る）
  final String itemId;

  /// 買ったときのアイテム名
  final String itemName;

  /// 購入完了にした人の uid
  final String byUid;

  /// 購入完了にした人の、その時点の表示名
  final String byName;

  /// 購入完了にした日時（保存中は null）
  final DateTime? purchasedAt;
}
