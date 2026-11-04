import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../firebase/firebase_providers.dart';
import '../../features/items/domain/category.dart';

/// デモ（お試し版）用の Firebase の差し替え。
///
/// Firestore と Authentication を、端末のメモリ上で動く代わりのものに置き換える。
/// サーバーには何も送らず、ページを読み込み直すとサンプルデータの状態に戻る。
/// ログインは Google を使わず、デモ用のユーザーとして入る。
Future<List<Override>> demoOverrides() async {
  final db = FakeFirebaseFirestore();
  await _seed(db, DateTime.now());
  final auth = MockFirebaseAuth(signedIn: true, mockUser: _me);
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
  ];
}

const _meEmail = 'demo@example.com';

final _me = MockUser(
  uid: 'demo-me',
  email: _meEmail,
  displayName: 'あなた',
  isEmailVerified: true,
);

/// ほかの家族（サンプル）
const _hanako = (uid: 'demo-hanako', name: 'はなこ');
const _taro = (uid: 'demo-taro', name: 'たろう');

/// サンプルデータを入れる
Future<void> _seed(FirebaseFirestore db, DateTime now) async {
  Timestamp ago({int days = 0, int hours = 0, int minutes = 0}) =>
      Timestamp.fromDate(
        now.subtract(Duration(days: days, hours: hours, minutes: minutes)),
      );

  // ---- 利用者 ----
  // 自分は管理者（ユーザー管理・改善意見の一覧も試せるようにする）
  await db.collection('allowedUsers').doc(_meEmail).set({
    'memo': 'デモ用のアカウント',
    'admin': true,
  });
  await db.collection('allowedUsers').doc('hanako@example.com').set({
    'memo': 'はなこ',
    'admin': false,
  });
  await db.collection('allowedUsers').doc('taro@example.com').set({
    'memo': 'たろう',
    'admin': false,
  });
  await db.collection('accessRequests').doc('jiro@example.com').set({
    'uid': 'demo-jiro',
    'displayName': 'じろう',
    'requestedAt': ago(hours: 3),
  });
  for (final member in [
    (uid: _me.uid, name: 'あなた'),
    _hanako,
    _taro,
  ]) {
    await db.collection('users').doc(member.uid).set({
      'displayName': member.name,
      'createdAt': ago(days: 30),
      'updatedAt': ago(days: 30),
    });
  }

  // ---- カテゴリ ----
  final categories = [
    (id: Category.waterId, name: '水回り', order: 1),
    (id: 'demo-kitchen', name: 'キッチン', order: 2),
    (id: 'demo-laundry', name: '洗濯', order: 3),
    (id: Category.otherId, name: 'その他', order: 9999),
  ];
  for (final category in categories) {
    await db.collection('categories').doc(category.id).set({
      'name': category.name,
      'order': category.order,
      'createdAt': ago(days: 30),
      'updatedAt': ago(days: 30),
    });
  }

  // ---- アイテム ----
  Map<String, Object?> purchase(
    String state,
    ({String uid, String name}) by,
    Timestamp at,
  ) => {'state': state, 'byUid': by.uid, 'byName': by.name, 'at': at};

  final items = [
    (
      name: 'トイレットペーパー',
      categoryId: Category.waterId,
      status: 'low',
      memo: '12ロール・ダブル',
      by: _hanako,
      at: ago(hours: 5),
      purchase: purchase('planned', _hanako, ago(hours: 4)),
    ),
    (
      name: 'シャンプー（詰め替え）',
      categoryId: Category.waterId,
      status: 'empty',
      memo: '',
      by: _taro,
      at: ago(days: 1),
      purchase: null,
    ),
    (
      name: 'ハンドソープ',
      categoryId: Category.waterId,
      status: 'sufficient',
      memo: '',
      by: _hanako,
      at: ago(days: 6),
      purchase: null,
    ),
    (
      name: '歯みがき粉',
      categoryId: Category.waterId,
      status: 'sufficient',
      memo: '',
      by: _taro,
      at: ago(days: 12),
      purchase: null,
    ),
    (
      name: '食器用洗剤',
      categoryId: 'demo-kitchen',
      status: 'low',
      memo: '',
      by: _taro,
      at: ago(hours: 2),
      purchase: purchase('in_cart', _taro, ago(minutes: 10)),
    ),
    (
      name: 'ラップ',
      categoryId: 'demo-kitchen',
      status: 'sufficient',
      memo: '30cm幅',
      by: _hanako,
      at: ago(days: 3),
      purchase: null,
    ),
    (
      name: 'キッチンペーパー',
      categoryId: 'demo-kitchen',
      status: 'empty',
      memo: '',
      by: _hanako,
      at: ago(hours: 20),
      purchase: null,
    ),
    (
      name: '洗濯用洗剤',
      categoryId: 'demo-laundry',
      status: 'sufficient',
      memo: '',
      by: _taro,
      at: ago(days: 8),
      purchase: null,
    ),
    (
      name: '柔軟剤',
      categoryId: 'demo-laundry',
      status: 'low',
      memo: '',
      by: _hanako,
      at: ago(days: 2),
      purchase: null,
    ),
    (
      name: '電池（単3）',
      categoryId: Category.otherId,
      status: 'sufficient',
      memo: '',
      by: _taro,
      at: ago(days: 20),
      purchase: null,
    ),
  ];
  // 購入履歴をアイテムに結びつけるための、名前 → ドキュメント ID
  final itemIds = <String, String>{};
  for (final item in items) {
    final ref = db.collection('items').doc();
    itemIds[item.name] = ref.id;
    await ref.set({
      'name': item.name,
      'categoryId': item.categoryId,
      'status': item.status,
      'memo': item.memo,
      'barcodes': <String>[],
      'purchase': item.purchase,
      'createdAt': ago(days: 30),
      'updatedAt': item.at,
      'updatedByUid': item.by.uid,
      'updatedByName': item.by.name,
    });
  }

  // ---- 購入履歴 ----
  final history = [
    (name: 'ハンドソープ', by: _hanako, at: ago(days: 6)),
    (name: 'ラップ', by: _taro, at: ago(days: 3)),
    (name: '洗濯用洗剤', by: _taro, at: ago(days: 8)),
    (name: 'トイレットペーパー', by: _hanako, at: ago(days: 18)),
  ];
  for (final record in history) {
    await db.collection('purchaseHistory').add({
      'itemId': itemIds[record.name] ?? '',
      'itemName': record.name,
      'byUid': record.by.uid,
      'byName': record.by.name,
      'purchasedAt': record.at,
    });
  }

  // ---- 改善意見 ----
  await db.collection('feedback').add({
    'type': 'request',
    'body': '買い物リストをお店ごとに分けたい',
    'appVersion': '',
    'byUid': _me.uid,
    'byName': 'あなた',
    'createdAt': ago(days: 4),
    'status': 'in_progress',
    'devMemo': '検討中',
  });
  await db.collection('feedback').add({
    'type': 'bug',
    'body': 'カテゴリを閉じた状態が覚えられないことがある',
    'appVersion': '',
    'byUid': _hanako.uid,
    'byName': _hanako.name,
    'createdAt': ago(days: 9),
    'status': 'done',
    'devMemo': '',
  });
}
