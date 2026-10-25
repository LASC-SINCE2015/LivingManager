import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/domain/member.dart';
import '../domain/feedback_rules.dart';
import '../domain/user_feedback.dart';

/// 改善意見（feedback）の読み書き
class FeedbackRepository {
  FeedbackRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _db.collection('feedback');

  /// 改善意見を送る
  Future<void> submit({
    required FeedbackType type,
    required String body,
    required String appVersion,
    required Member actor,
  }) => _feedback.add({
    'type': type.value,
    'body': body,
    'appVersion': appVersion,
    'byUid': actor.uid,
    'byName': actor.displayName,
    'createdAt': FieldValue.serverTimestamp(),
    'status': FeedbackStatus.open.value,
    'devMemo': '',
  });

  /// 自分が送った意見（新しい順）。
  ///
  /// 並べ替えはアプリ側で行い、複合インデックスを不要にする。
  Stream<List<UserFeedback>> watchMine(String uid) => _feedback
      .where('byUid', isEqualTo: uid)
      .snapshots()
      .map((snap) => sortNewestFirst(snap.docs.map(_toFeedback)));

  /// すべての意見（新しい順。開発者用）
  Stream<List<UserFeedback>> watchAll() => _feedback.snapshots().map(
    (snap) => sortNewestFirst(snap.docs.map(_toFeedback)),
  );

  Future<void> updateStatus(String id, FeedbackStatus status) =>
      _feedback.doc(id).update({
        'status': status.value,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateMemo(String id, String memo) => _feedback.doc(id).update({
    'devMemo': memo,
    'statusUpdatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _feedback.doc(id).delete();

  static UserFeedback _toFeedback(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final createdAt = data['createdAt'];
    return UserFeedback(
      id: doc.id,
      type: FeedbackType.fromValue(data['type'] as String?),
      body: data['body'] as String? ?? '',
      appVersion: data['appVersion'] as String? ?? '',
      byUid: data['byUid'] as String? ?? '',
      byName: data['byName'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      status: FeedbackStatus.fromValue(data['status'] as String?),
      devMemo: data['devMemo'] as String? ?? '',
    );
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(ref.watch(firestoreProvider)),
);
