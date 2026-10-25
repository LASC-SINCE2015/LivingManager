import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../items/data/items_repository.dart';
import '../data/auth_repository.dart';
import '../data/member_repository.dart';
import '../domain/access_status.dart';
import '../domain/member.dart';

/// ログイン状態
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// ログイン中のユーザー（未ログイン・確認中は null）
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).value,
);

/// 利用を許可されたアカウントかの判定と、使い始める準備
/// （メンバー登録・初期カテゴリの作成）
final accessCheckProvider = FutureProvider<AccessStatus>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return AccessStatus.signedOut;

  final allowed = await ref.read(authRepositoryProvider).isAllowed(user);
  if (!allowed) return AccessStatus.denied;

  await ref.read(memberRepositoryProvider).ensureExists(user);
  await ref.read(itemsRepositoryProvider).ensureInitialCategories();
  return AccessStatus.allowed;
});

/// 画面の出し分けに使う判定結果
final accessStatusProvider = Provider<AccessStatus>((ref) {
  final check = ref.watch(accessCheckProvider);
  if (check.isLoading) return AccessStatus.checking;
  if (check.hasError) return AccessStatus.error;
  return check.requireValue;
});

/// 利用を許可されていなかったメールアドレス（アクセス権限エラー画面に表示する）
class DeniedEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? email) => state = email;
}

final deniedEmailProvider = NotifierProvider<DeniedEmailNotifier, String?>(
  DeniedEmailNotifier.new,
);

/// 自分のメンバー情報（表示名）
final currentMemberProvider = StreamProvider<Member?>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(memberRepositoryProvider).watch(uid);
});

/// 更新者・担当者として記録する自分の情報
final actorProvider = Provider<Member?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final member = ref.watch(currentMemberProvider).value;
  return Member(
    uid: user.uid,
    displayName: member?.displayName ?? MemberRepository.initialName(user),
  );
});
