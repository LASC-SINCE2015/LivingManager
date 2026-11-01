import 'purchase_record.dart';

/// 購入履歴を残す期間（これより古い記録は、アプリを開いたときに消す）
const historyRetention = Duration(days: 365);

/// 消してよい記録の境目（これより前に購入完了にした記録を消す）。
///
/// 端末の時計が進んでいても、ルール（サーバー時刻で判定）で拒否されない
/// よう、残す期間より 1 日だけ余分に残す。
DateTime expiryCutoff(DateTime now) =>
    now.subtract(historyRetention + const Duration(days: 1));

/// 新しい順に並べる（保存中で日時が未確定のものは一番上）
List<PurchaseRecord> sortRecordsNewestFirst(Iterable<PurchaseRecord> list) {
  return list.toList()..sort((a, b) {
    final at = a.purchasedAt;
    final bt = b.purchasedAt;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  });
}

/// 日付を「2026年10月25日（日）」の形で表す（保存中の null は「たった今」）
String formatPurchaseDate(DateTime? time) {
  if (time == null) return 'たった今';
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  return '${time.year}年${time.month}月${time.day}日'
      '（${weekdays[time.weekday - 1]}）';
}
