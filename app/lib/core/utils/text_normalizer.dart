/// 名前の重複チェック用に文字列をそろえる。
///
/// 前後の空白を除き、全角英数字・記号を半角に、カタカナをひらがなに、
/// 英字を小文字にする。
String normalizeForCompare(String input) {
  final buffer = StringBuffer();
  for (var code in input.trim().runes) {
    if (code >= 0xFF01 && code <= 0xFF5E) {
      // 全角英数字・記号 → 半角
      code -= 0xFEE0;
    } else if (code == 0x3000) {
      // 全角スペース → 半角スペース
      code = 0x20;
    } else if (code >= 0x30A1 && code <= 0x30F6) {
      // カタカナ → ひらがな
      code -= 0x60;
    }
    buffer.writeCharCode(code);
  }
  return buffer.toString().toLowerCase();
}
