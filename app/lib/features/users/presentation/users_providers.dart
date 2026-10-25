import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/users_repository.dart';
import '../domain/access_request.dart';
import '../domain/allowed_user.dart';

/// ログイン中の uid（サインアウトしたら購読をやめるために使う）
final _uidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.uid)),
);

/// 自分の追加の依頼がすでにあるか（アクセス権限エラー画面で使う）
final myAccessRequestProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.read(usersRepositoryProvider).hasRequested(user);
});

/// 追加の依頼の一覧（古い順）。開発者のときだけ画面から購読する
final accessRequestsProvider = StreamProvider<List<AccessRequest>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(usersRepositoryProvider).watchRequests();
});

/// 許可済みのアカウントの一覧。開発者のときだけ画面から購読する
final allowedUsersProvider = StreamProvider<List<AllowedUser>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(usersRepositoryProvider).watchAllowedUsers();
});
