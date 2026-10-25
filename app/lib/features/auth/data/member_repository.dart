import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/member.dart';

/// 家族メンバー（users コレクション）の読み書き
class MemberRepository {
  MemberRepository(this._db);

  final FirebaseFirestore _db;

  static const maxNameLength = 20;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<Member?> watch(String uid) => _doc(uid).snapshots().map((snap) {
    final data = snap.data();
    if (data == null) return null;
    return Member(uid: uid, displayName: data['displayName'] as String? ?? '');
  });

  /// 初回ログイン時に、自分のドキュメントがなければ作る
  Future<void> ensureExists(User user) async {
    final snap = await _doc(user.uid).get();
    if (snap.exists) return;
    await _doc(user.uid).set({
      'displayName': initialName(user),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) =>
      _doc(uid).update({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// 表示名の初期値（Google アカウントの名前。なければメールアドレスの @ より前）
  static String initialName(User user) {
    final googleName = (user.displayName ?? '').trim();
    final name = googleName.isNotEmpty
        ? googleName
        : (user.email ?? 'メンバー').split('@').first;
    return name.length > maxNameLength
        ? name.substring(0, maxNameLength)
        : name;
  }
}

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(ref.watch(firestoreProvider)),
);
