import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// ログイン・ログアウトと、利用を許可されたアカウントかの判定
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    await _auth.signInWithPopup(provider);
  }

  Future<void> signOut() => _auth.signOut();

  /// 利用を許可されたアカウントか
  Future<bool> isAllowed(User user) async {
    final email = user.email;
    if (email == null || !user.emailVerified) return false;
    try {
      final doc = await _db
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .get();
      return doc.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// 開発者（改善意見の一覧を使える家族）かどうかを判定する
  Future<bool> isDeveloper(User user) async {
    final email = user.email;
    if (email == null || !user.emailVerified) return false;
    try {
      final doc = await _db
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .get();
      return doc.data()?['admin'] == true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);
