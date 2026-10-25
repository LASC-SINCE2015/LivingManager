/// アイテムの在庫状況
enum StockStatus {
  sufficient('sufficient', '十分'),
  low('low', '残りわずか'),
  empty('empty', '切れてる');

  const StockStatus(this.value, this.label);

  /// Firestore に保存する値
  final String value;

  /// 画面に表示する名前
  final String label;

  /// 買い物リストに出るか（残りわずか・切れてる）
  bool get needsBuying => this != StockStatus.sufficient;

  static StockStatus fromValue(String? value) => StockStatus.values.firstWhere(
    (status) => status.value == value,
    orElse: () => StockStatus.sufficient,
  );
}
