import '../../items/domain/item.dart';

/// LINE で買い物を頼むときの文面。
///
/// ```
/// 買い物をお願いします。
/// ・トイレットペーパー（12ロール）
/// ・食器用洗剤
/// ```
///
/// メモがあれば、買うときに必要な情報なので（ ）で添える（改行は空白にする）。
String buildLineRequestText(List<Item> items) {
  final lines = [
    for (final item in items)
      item.memo.trim().isEmpty
          ? '・${item.name}'
          : '・${item.name}（${item.memo.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ')}）',
  ];
  return ['買い物をお願いします。', ...lines].join('\n');
}

/// LINE の「送信先を選んで送る」画面を開く URL。
///
/// スマホでは LINE アプリが開き、送る相手（友だち・グループ）を選べる。
/// 空白が「+」のまま届かないよう、`%20` の形でエンコードする。
Uri lineShareUri(String text) =>
    Uri.parse('https://line.me/R/share?text=${Uri.encodeComponent(text)}');
