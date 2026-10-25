import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/access_request.dart';
import '../domain/allowed_user.dart';
import '../domain/user_rules.dart';

/// 追加の依頼（accessRequests）と許可リスト（allowedUsers）の読み書き。
///
/// 許可リストへの追加は承認のときだけ行う。変更・削除は Firebase コンソールから行う。
class UsersRepository {
  UsersRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('accessRequests');

  CollectionReference<Map<String, dynamic>> get _allowedUsers =>
      _db.collection('allowedUsers');

  /// 自分の依頼がすでにあるか（許可されていないアカウント用）
  Future<bool> hasRequested(User user) async {
    final email = user.email;
    if (email == null) return false;
    final doc = await _requests.doc(email.toLowerCase()).get();
    return doc.exists;
  }

  /// 管理者に追加を依頼する（許可されていないアカウント用）
  Future<void> requestAccess(User user) {
    final name = (user.displayName ?? '').trim();
    return _requests.doc(user.email!.toLowerCase()).set({
      'uid': user.uid,
      'displayName': name.length > requestNameMaxLength
          ? name.substring(0, requestNameMaxLength)
          : name,
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 依頼の一覧（古い順。開発者用）
  Stream<List<AccessRequest>> watchRequests() => _requests.snapshots().map(
    (snap) => sortRequestsOldestFirst(snap.docs.map(_toRequest)),
  );

  /// 許可済みのアカウントの一覧（開発者用）
  Stream<List<AllowedUser>> watchAllowedUsers() => _allowedUsers
      .snapshots()
      .map((snap) => sortAllowedUsers(snap.docs.map(_toAllowedUser)));

  /// 依頼を承認する（許可リストへの追加と依頼の削除を同時に行う）
  Future<void> approve(
    String email, {
    required String memo,
    required bool admin,
  }) {
    final batch = _db.batch()
      ..set(_allowedUsers.doc(email), {
        'memo': memo,
        'admin': admin,
        'approvedAt': FieldValue.serverTimestamp(),
      })
      ..delete(_requests.doc(email));
    return batch.commit();
  }

  /// 依頼を却下する（依頼を削除する。本人はもう一度依頼できる）
  Future<void> reject(String email) => _requests.doc(email).delete();

  static AccessRequest _toRequest(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final requestedAt = data['requestedAt'];
    return AccessRequest(
      email: doc.id,
      displayName: data['displayName'] as String? ?? '',
      requestedAt: requestedAt is Timestamp ? requestedAt.toDate() : null,
    );
  }

  static AllowedUser _toAllowedUser(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return AllowedUser(
      email: doc.id,
      memo: data['memo'] as String? ?? '',
      admin: data['admin'] == true,
    );
  }
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(firestoreProvider)),
);
