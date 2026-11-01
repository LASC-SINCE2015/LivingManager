import 'item.dart';

/// 1 つのアイテムに登録できるバーコードの数
const maxBarcodesPerItem = 10;

/// 読み取った・入力したバーコードを、保存する形にそろえる（使えない値なら null）。
///
/// - 空白とハイフンを取り除き、数字だけにする。
/// - JAN（EAN）-8・JAN（EAN）-13・UPC-A（12 桁）・ITF-14 を受け付け、
///   末尾のチェックデジットが合わないもの（読み間違い・打ち間違い）は受け付けない。
/// - UPC-A は先頭に 0 を付けて 13 桁にする（同じ商品を EAN-13 として読んだときと
///   同じ値になるようにするため）。
String? normalizeBarcode(String raw) {
  final code = raw.replaceAll(RegExp(r'[\s\-－　]'), '');
  if (!RegExp(r'^[0-9]+$').hasMatch(code)) return null;
  if (![8, 12, 13, 14].contains(code.length)) return null;
  if (!_hasValidCheckDigit(code)) return null;
  return code.length == 12 ? '0$code' : code;
}

/// GTIN のチェックデジット（モジュラス 10・ウェイト 3/1）が合っているか
bool _hasValidCheckDigit(String code) {
  var sum = 0;
  // 右から 2 桁目を 3 倍、3 桁目を 1 倍…と交互に掛ける
  for (var i = code.length - 2, weight = 3; i >= 0; i--) {
    sum += int.parse(code[i]) * weight;
    weight = weight == 3 ? 1 : 3;
  }
  final check = (10 - sum % 10) % 10;
  return check == int.parse(code[code.length - 1]);
}

/// [barcode] が登録されているアイテム（[exceptItemId] のアイテムは除く）
Item? findItemByBarcode(
  List<Item> items,
  String barcode, {
  String? exceptItemId,
}) => items
    .where((item) => item.id != exceptItemId && item.barcodes.contains(barcode))
    .firstOrNull;
