import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/domain/member.dart';
import '../domain/category.dart';
import '../domain/claim_result.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';

/// アイテム（items）とカテゴリ（categories）の読み書き
class ItemsRepository {
  ItemsRepository(this._db);

  final FirebaseFirestore _db;

  static const _initialCategories = [
    Category(id: Category.waterId, name: '水回り', order: 1),
    Category(id: Category.otherId, name: 'その他', order: 9999),
  ];

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('items');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('categories');

  // ---- 読み取り ----

  /// カテゴリを表示順に並べて返す
  Stream<List<Category>> watchCategories() =>
      _categories.snapshots().map((snap) {
        final list = snap.docs.map(_toCategory).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Stream<List<Item>> watchItems() => _items.snapshots().map(
    (snap) => snap.docs.map(_toItem).toList(),
  );

  // ---- カテゴリ ----

  /// 初期カテゴリがなければ作る（ID を固定しているので、同時に作っても重複しない）
  Future<void> ensureInitialCategories() async {
    for (final category in _initialCategories) {
      final ref = _categories.doc(category.id);
      final snap = await ref.get();
      if (snap.exists) continue;
      await ref.set({
        'name': category.name,
        'order': category.order,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// カテゴリを「その他」のすぐ上に追加し、そのドキュメント ID を返す
  Future<String> addCategory(String name, List<Category> current) async {
    final maxOrder = current
        .where((c) => c.id != Category.otherId)
        .fold<int>(0, (max, c) => c.order > max ? c.order : max);
    final ref = _categories.doc();
    await ref.set({
      'name': name,
      'order': maxOrder + 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ---- アイテム ----

  Future<void> addItem({
    required String name,
    required String categoryId,
    required StockStatus status,
    required String memo,
    required Member actor,
  }) => _items.add({
    'name': name,
    'categoryId': categoryId,
    'status': status.value,
    'memo': memo,
    'purchase': null,
    'createdAt': FieldValue.serverTimestamp(),
    ..._updatedFields(actor),
  });

  Future<void> updateItem(
    String itemId, {
    required String name,
    required String categoryId,
    required StockStatus status,
    required String memo,
    required Member actor,
  }) => _items.doc(itemId).update({
    'name': name,
    'categoryId': categoryId,
    'status': status.value,
    'memo': memo,
    // 「十分」に戻したら担当・カゴ済みも解除する
    if (!status.needsBuying) 'purchase': null,
    ..._updatedFields(actor),
  });

  Future<void> deleteItem(String itemId) => _items.doc(itemId).delete();

  Future<void> changeStatus(String itemId, StockStatus status, Member actor) =>
      _items.doc(itemId).update({
        'status': status.value,
        if (!status.needsBuying) 'purchase': null,
        ..._updatedFields(actor),
      });

  // ---- 買い物 ----

  /// 担当者になる（[toCart] が true ならカゴ済みにする）。
  ///
  /// ほかの人が先に担当していた場合は上書きしない。ただし確認のうえ
  /// 代わりに担当する相手を [takeOverFromUid] で渡した場合は、その人の担当中を
  /// 上書きする（ほかの人のカゴ済みは上書きしない）。
  Future<ClaimResult> claim(
    String itemId,
    Member actor, {
    required bool toCart,
    String? takeOverFromUid,
  }) {
    final ref = _items.doc(itemId);
    return _db.runTransaction<ClaimResult>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return const ClaimItemGone();
      final item = _toItem(snap);
      if (!item.status.needsBuying) return const ClaimItemGone();

      final current = item.purchase;
      if (current != null && current.byUid != actor.uid) {
        if (current.isInCart || current.byUid != takeOverFromUid) {
          return ClaimConflicted(current.byName);
        }
      }
      tx.update(ref, {
        'purchase': _purchaseFields(
          toCart ? PurchaseState.inCart : PurchaseState.planned,
          actor,
        ),
      });
      return const ClaimSucceeded();
    });
  }

  /// 自分の担当を解除する
  Future<void> release(String itemId, Member actor) =>
      _updateMyPurchase(itemId, actor, (_) => {'purchase': null});

  /// 自分のカゴ済みのチェックを外し、担当中に戻す
  Future<void> uncheck(String itemId, Member actor) => _updateMyPurchase(
    itemId,
    actor,
    (purchase) => purchase.isInCart
        ? {'purchase.state': PurchaseState.planned.value}
        : null,
  );

  /// 自分がカゴ済みにしたアイテムをまとめて「十分」に戻す
  Future<void> completePurchase(List<Item> items, Member actor) {
    final batch = _db.batch();
    for (final item in items) {
      batch.update(_items.doc(item.id), {
        'status': StockStatus.sufficient.value,
        'purchase': null,
        ..._updatedFields(actor),
      });
    }
    return batch.commit();
  }

  /// 自分が担当しているときだけ purchase を更新する（[change] が null なら何もしない）
  Future<void> _updateMyPurchase(
    String itemId,
    Member actor,
    Map<String, Object?>? Function(Purchase purchase) change,
  ) {
    final ref = _items.doc(itemId);
    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final purchase = _toItem(snap).purchase;
      if (purchase == null || purchase.byUid != actor.uid) return;
      final data = change(purchase);
      if (data != null) tx.update(ref, data);
    });
  }

  // ---- 変換 ----

  /// 在庫情報を更新した人・日時
  static Map<String, Object> _updatedFields(Member actor) => {
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedByUid': actor.uid,
    'updatedByName': actor.displayName,
  };

  static Map<String, Object> _purchaseFields(
    PurchaseState state,
    Member actor,
  ) => {
    'state': state.value,
    'byUid': actor.uid,
    'byName': actor.displayName,
    'at': FieldValue.serverTimestamp(),
  };

  static Category _toCategory(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Category(
      id: doc.id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  static Item _toItem(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Item(
      id: doc.id,
      name: data['name'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? Category.otherId,
      status: StockStatus.fromValue(data['status'] as String?),
      memo: data['memo'] as String? ?? '',
      purchase: _toPurchase(data['purchase']),
      updatedAt: _toDate(data['updatedAt']),
      updatedByUid: data['updatedByUid'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? '',
    );
  }

  static Purchase? _toPurchase(Object? value) {
    if (value is! Map) return null;
    return Purchase(
      state: PurchaseState.fromValue(value['state'] as String?),
      byUid: value['byUid'] as String? ?? '',
      byName: value['byName'] as String? ?? '',
      at: _toDate(value['at']),
    );
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}

final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(firestoreProvider)),
);
