/// 日時を「2026/10/25 09:05」の形で表す。
///
/// [time] が null のときは保存中（サーバー時刻がまだ決まっていない）なので
/// 「送信中」とする。
String formatDateTime(DateTime? time) {
  if (time == null) return '送信中';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}/${two(time.month)}/${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
