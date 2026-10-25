import 'user_feedback.dart';

/// 本文の最大文字数
const feedbackBodyMaxLength = 1000;

/// 開発者メモの最大文字数
const devMemoMaxLength = 500;

/// 本文の入力チェック（問題なければ null）
String? validateFeedbackBody(String body) {
  final text = body.trim();
  if (text.isEmpty) return '本文を入力してください';
  if (text.length > feedbackBodyMaxLength) {
    return '$feedbackBodyMaxLength文字以内で入力してください';
  }
  return null;
}

/// 開発者メモの入力チェック（問題なければ null）
String? validateDevMemo(String memo) {
  if (memo.trim().length > devMemoMaxLength) {
    return '$devMemoMaxLength文字以内で入力してください';
  }
  return null;
}

/// 新しい順に並べる（保存中で日時が未確定のものは一番上）
List<UserFeedback> sortNewestFirst(Iterable<UserFeedback> list) {
  return list.toList()..sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  });
}

/// 状態・種類で絞り込む（null はすべて）
List<UserFeedback> filterFeedback(
  Iterable<UserFeedback> list, {
  FeedbackStatus? status,
  FeedbackType? type,
}) {
  return list
      .where((f) => status == null || f.status == status)
      .where((f) => type == null || f.type == type)
      .toList();
}

/// 状態ごとの件数（種類の絞り込みを反映した一覧から数える）
Map<FeedbackStatus, int> countByStatus(Iterable<UserFeedback> list) {
  final counts = {for (final status in FeedbackStatus.values) status: 0};
  for (final f in list) {
    counts[f.status] = counts[f.status]! + 1;
  }
  return counts;
}
