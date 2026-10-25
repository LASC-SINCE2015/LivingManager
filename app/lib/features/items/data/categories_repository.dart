import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/category.dart';

/// カテゴリ管理（名前変更・並べ替え・削除）の書き込み。
///
/// 読み取りと追加は ItemsRepository が担う。
class CategoriesRepository {
  CategoriesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('categories');

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('items');

  Future<void> rename(String categoryId, String name) =>
      _categories.doc(categoryId).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// 「その他」を除くカテゴリを [orderedIds] の順に並べ直す（order を 1 から振り直す）
  Future<void> reorder(List<String> orderedIds) {
    final batch = _db.batch();
    var order = 1;
    for (final id in orderedIds) {
      if (id == Category.otherId) continue;
      batch.update(_categories.doc(id), {
        'order': order++,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  /// カテゴリを削除する。所属していたアイテムは「その他」に移す。
  ///
  /// アイテムの更新者・更新日時は変えない（在庫情報の変更ではないため）。
  Future<void> delete(String categoryId) async {
    if (categoryId == Category.otherId) {
      throw ArgumentError('「その他」は削除できません');
    }
    final items = await _items.where('categoryId', isEqualTo: categoryId).get();
    final batch = _db.batch();
    for (final doc in items.docs) {
      batch.update(doc.reference, {'categoryId': Category.otherId});
    }
    batch.delete(_categories.doc(categoryId));
    await batch.commit();
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(firestoreProvider)),
);
