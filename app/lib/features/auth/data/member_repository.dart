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

  /// 自分の並び順（カテゴリ ID → アイテム ID を表示順に並べた配列）
  Stream<Map<String, List<String>>> watchItemOrder(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final value = snap.data()?['itemOrder'];
        if (value is! Map) return const {};
        return {
          for (final entry in value.entries)
            if (entry.key is String && entry.value is List)
              entry.key as String: [
                for (final id in entry.value as List)
                  if (id is String) id,
              ],
        };
      });

  /// あるカテゴリの並び順を丸ごと保存する
  Future<void> saveCategoryOrder(
    String uid,
    String categoryId,
    List<String> itemIds,
  ) => _doc(uid).update({
    FieldPath(['itemOrder', categoryId]): itemIds,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// 自分が閉じている（中身を隠している）カテゴリの ID
  Stream<Set<String>> watchHiddenCategories(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final value = snap.data()?['hiddenCategories'];
        if (value is! List) return const {};
        return {
          for (final id in value)
            if (id is String) id,
        };
      });

  /// 閉じているカテゴリの ID を丸ごと保存する
  Future<void> saveHiddenCategories(String uid, Set<String> categoryIds) =>
      _doc(uid).update({
        'hiddenCategories': categoryIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
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
