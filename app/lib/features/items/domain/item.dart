import 'stock_status.dart';

/// 買い物の状況の段階
enum PurchaseState {
  /// 担当中（買います）
  planned('planned'),

  /// カゴ済み
  inCart('in_cart');

  const PurchaseState(this.value);

  /// Firestore に保存する値
  final String value;

  static PurchaseState fromValue(String? value) => PurchaseState.values
      .firstWhere((state) => state.value == value, orElse: () => planned);
}

/// 買い物の状況（担当者・カゴ済み）
class Purchase {
  const Purchase({
    required this.state,
    required this.byUid,
    required this.byName,
    required this.at,
  });

  final PurchaseState state;

  /// 担当者の uid
  final String byUid;

  /// 担当者の、その時点の表示名
  final String byName;

  /// 担当・カゴ済みにした日時（保存中は null）
  final DateTime? at;

  bool get isInCart => state == PurchaseState.inCart;

  /// 担当・カゴ済みにしてから 24 時間以上たっているか
  bool isStale(DateTime now) =>
      at != null && now.difference(at!) >= const Duration(hours: 24);
}

/// 管理する日用品（items コレクションの 1 件）
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.status,
    required this.memo,
    required this.purchase,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
  });

  final String id;
  final String name;
  final String categoryId;
  final StockStatus status;
  final String memo;

  /// 買い物の状況。誰も担当していなければ null
  final Purchase? purchase;

  /// 在庫情報を最後に更新した日時（保存中は null）
  final DateTime? updatedAt;
  final String updatedByUid;

  /// 最後に更新した人の、その時点の表示名
  final String updatedByName;
}
