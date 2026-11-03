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

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection('purchaseHistory');

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
    List<String> barcodes = const [],
    required Member actor,
  }) => _items.add({
    'name': name,
    'categoryId': categoryId,
    'status': status.value,
    'memo': memo,
    'barcodes': barcodes,
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
    required List<String> barcodes,
    required Member actor,
  }) => _items.doc(itemId).update({
    'name': name,
    'categoryId': categoryId,
    'status': status.value,
    'memo': memo,
    'barcodes': barcodes,
    // 「十分」に戻したら担当・カゴ済みも解除する
    if (!status.needsBuying) 'purchase': null,
    ..._updatedFields(actor),
  });

  Future<void> deleteItem(String itemId) => _items.doc(itemId).delete();

  /// 既存のアイテムにバーコードを追加する。
  ///
  /// 在庫の状況は変わらないので、更新者・更新日時は変えない（担当・カゴ済みと同じ）。
  Future<void> addBarcode(String itemId, String barcode) =>
      _items.doc(itemId).update({
        'barcodes': FieldValue.arrayUnion([barcode]),
      });

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

  /// 自分がカゴ済みにしたアイテムをまとめて「十分」に戻し、購入履歴に記録する。
  ///
  /// 「元に戻す」で記録を消せるよう、アイテム ID → 記録のドキュメント ID を返す。
  Future<Map<String, String>> completePurchase(
    List<Item> items,
    Member actor,
  ) async {
    final batch = _db.batch();
    final recordIds = <String, String>{};
    for (final item in items) {
      batch.update(_items.doc(item.id), {
        'status': StockStatus.sufficient.value,
        'purchase': null,
        ..._updatedFields(actor),
      });
      final record = _history.doc();
      batch.set(record, {
        'itemId': item.id,
        'itemName': item.name,
        'byUid': actor.uid,
        'byName': actor.displayName,
        'purchasedAt': FieldValue.serverTimestamp(),
      });
      recordIds[item.id] = record.id;
    }
    await batch.commit();
    return recordIds;
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

  // ---- 元に戻す ----

  /// ステータス変更を元に戻す。戻せたら true。
  ///
  /// 自分が [after] に変えたままのとき（ほかの人が変更していないとき）だけ、
  /// [before] に戻す。更新者は自分になる。担当・カゴ済みは次のように扱う。
  /// - [before] が「十分」なら解除する。
  /// - 「十分」に変えたことで解除した担当（[purchaseBefore]）は、自分の担当なら戻す。
  ///   ほかの人の担当は、本人以外が書けないため解除したままにする。
  /// - それ以外（残りわずか ⇄ 切れてる）は今の担当をそのまま残す。
  Future<bool> revertStatus(
    String itemId,
    Member actor, {
    required StockStatus before,
    required StockStatus after,
    required Purchase? purchaseBefore,
  }) {
    final ref = _items.doc(itemId);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final current = _toItem(snap);
      if (current.updatedByUid != actor.uid || current.status != after) {
        return false;
      }

      final data = <String, Object?>{
        'status': before.value,
        ..._updatedFields(actor),
      };
      if (!before.needsBuying) {
        data['purchase'] = null;
      } else if (!after.needsBuying) {
        data['purchase'] =
            purchaseBefore != null && purchaseBefore.byUid == actor.uid
            ? _purchaseFieldsOf(purchaseBefore)
            : null;
      }
      tx.update(ref, data);
      return true;
    });
  }

  /// 購入完了を元に戻し、戻せた件数を返す。
  ///
  /// [before] は購入完了の直前のアイテム（自分のカゴ済み）。自分が「十分」に
  /// したままのアイテムだけを、元のステータスとカゴ済みに戻し、そのアイテムの
  /// 購入履歴の記録（[recordIds] は [completePurchase] が返したもの）を消す。
  Future<int> revertPurchase(
    List<Item> before,
    Member actor, {
    required Map<String, String> recordIds,
  }) {
    return _db.runTransaction<int>((tx) async {
      // トランザクションでは、書き込みの前にすべて読み取る
      final snaps = [
        for (final item in before) await tx.get(_items.doc(item.id)),
      ];
      var reverted = 0;
      for (var i = 0; i < before.length; i++) {
        final snap = snaps[i];
        if (!snap.exists) continue;
        final current = _toItem(snap);
        final old = before[i];
        if (current.updatedByUid != actor.uid ||
            current.status.needsBuying ||
            current.purchase != null) {
          continue;
        }
        final purchase = old.purchase;
        tx.update(snap.reference, {
          'status': old.status.value,
          'purchase': purchase != null && purchase.byUid == actor.uid
              ? _purchaseFieldsOf(purchase)
              : null,
          ..._updatedFields(actor),
        });
        if (recordIds[old.id] case final recordId?) {
          tx.delete(_history.doc(recordId));
        }
        reverted++;
      }
      return reverted;
    });
  }

  // ---- 変換 ----

  /// 以前の担当・カゴ済みを書き戻すときの値（日時は元のまま）
  static Map<String, Object> _purchaseFieldsOf(Purchase purchase) => {
    'state': purchase.state.value,
    'byUid': purchase.byUid,
    'byName': purchase.byName,
    'at': purchase.at != null
        ? Timestamp.fromDate(purchase.at!)
        : FieldValue.serverTimestamp(),
  };

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
      barcodes: [
        for (final code in data['barcodes'] as List? ?? const [])
          if (code is String) code,
      ],
      purchase: _toPurchase(data['purchase']),
      createdAt: _toDate(data['createdAt']),
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
