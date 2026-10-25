import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/feedback_repository.dart';
import '../domain/user_feedback.dart';

/// ログイン中の uid（サインアウトしたら購読をやめるために使う）
final _uidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.uid)),
);

/// 自分が送った意見（新しい順）
final myFeedbackProvider = StreamProvider<List<UserFeedback>>((ref) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(feedbackRepositoryProvider).watchMine(uid);
});

/// すべての意見（新しい順）。開発者のときだけ画面から購読する
final allFeedbackProvider = StreamProvider<List<UserFeedback>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(feedbackRepositoryProvider).watchAll();
});
