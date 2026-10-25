/// アイテムの分類（categories コレクションの 1 件）
class Category {
  const Category({required this.id, required this.name, required this.order});

  /// 初期カテゴリ「水回り」のドキュメント ID
  static const waterId = 'water';

  /// 初期カテゴリ「その他」のドキュメント ID（削除不可・常に一番下）
  static const otherId = 'other';

  final String id;
  final String name;

  /// 表示順（小さいほど上）
  final int order;
}
