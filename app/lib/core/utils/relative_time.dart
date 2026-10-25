/// 更新日時を「たった今」「5分前」「昨日」などの形で表す。
///
/// [time] が null のときは保存中（サーバー時刻がまだ決まっていない）なので
/// 「たった今」とする。
String formatRelativeTime(DateTime? time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (time == null) return 'たった今';

  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inHours < 1) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  if (today.difference(day).inDays == 1) return '昨日';
  if (time.year == current.year) return '${time.month}月${time.day}日';
  return '${time.year}年${time.month}月${time.day}日';
}
