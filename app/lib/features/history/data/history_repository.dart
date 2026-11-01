import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/history_rules.dart';
import '../domain/purchase_record.dart';

/// 購入履歴（purchaseHistory）の読み取りと、期限切れの記録の削除。
///
/// 記録の追加と「元に戻す」での削除は、アイテムの更新と同時に行うため
/// `ItemsRepository`（購入完了）が行う。
class HistoryRepository {
  HistoryRepository(this._db);

  /// 1 回のバッチで消す件数の上限（Firestore のバッチは 500 件まで）
  static const _batchLimit = 500;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection('purchaseHistory');

  /// すべての記録（新しい順）
  Stream<List<PurchaseRecord>> watchAll() => _history.snapshots().map(
    (snap) => sortRecordsNewestFirst(snap.docs.map(_toRecord)),
  );

  /// 1 つのアイテムの記録（新しい順）
  Stream<List<PurchaseRecord>> watchForItem(String itemId) => _history
      .where('itemId', isEqualTo: itemId)
      .snapshots()
      .map((snap) => sortRecordsNewestFirst(snap.docs.map(_toRecord)));

  /// 残す期間を過ぎた記録を消し、消した件数を返す。
  ///
  /// Cloud Functions を使わないため、アプリを開いたときに呼ぶ。誰が消してもよい
  /// （ルールで、期間を過ぎた記録だけ消せるようにしている）。
  Future<int> deleteExpired(DateTime now) async {
    final snap = await _history
        .where('purchasedAt', isLessThan: Timestamp.fromDate(expiryCutoff(now)))
        .get();
    for (var i = 0; i < snap.docs.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final doc in snap.docs.skip(i).take(_batchLimit)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return snap.docs.length;
  }

  static PurchaseRecord _toRecord(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final at = data['purchasedAt'];
    return PurchaseRecord(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      byUid: data['byUid'] as String? ?? '',
      byName: data['byName'] as String? ?? '',
      purchasedAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(firestoreProvider)),
);
