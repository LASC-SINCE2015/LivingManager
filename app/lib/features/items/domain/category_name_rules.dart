import '../../../core/utils/text_normalizer.dart';
import 'category.dart';

/// カテゴリ名の最大文字数
const maxCategoryNameLength = 20;

/// カテゴリ名の入力チェック。問題がなければ null、あればエラーメッセージを返す。
///
/// [value] は前後の空白を除いたもの。名前を変更するときは、自分自身との
/// 重複を無視するため [excludeId] に変更中のカテゴリの ID を渡す。
String? validateCategoryName(
  String value,
  List<Category> categories, {
  String? excludeId,
}) {
  if (value.isEmpty) return 'カテゴリ名を入力してください';
  if (value.length > maxCategoryNameLength) {
    return '$maxCategoryNameLength文字以内で入力してください';
  }
  final key = normalizeForCompare(value);
  final duplicated = categories.any(
    (c) => c.id != excludeId && normalizeForCompare(c.name) == key,
  );
  if (duplicated) return '同じ名前のカテゴリがすでにあります';
  return null;
}
