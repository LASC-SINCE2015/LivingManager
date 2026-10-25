/// 改善意見の種類
enum FeedbackType {
  bug('bug', '不具合'),
  request('request', '要望'),
  other('other', 'その他');

  const FeedbackType(this.value, this.label);

  /// Firestore に保存する値
  final String value;

  /// 画面に出す名前
  final String label;

  static FeedbackType fromValue(String? value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () => FeedbackType.other,
  );
}

/// 改善意見の対応状況
enum FeedbackStatus {
  open('open', '未対応'),
  inProgress('in_progress', '対応中'),
  done('done', '対応済み'),
  wontFix('wont_fix', '見送り');

  const FeedbackStatus(this.value, this.label);

  /// Firestore に保存する値
  final String value;

  /// 画面に出す名前
  final String label;

  static FeedbackStatus fromValue(String? value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => FeedbackStatus.open,
  );
}

/// 改善意見（feedback コレクションの 1 件）
///
/// Flutter の `Feedback` クラスと名前が重ならないよう UserFeedback とする。
class UserFeedback {
  const UserFeedback({
    required this.id,
    required this.type,
    required this.body,
    required this.appVersion,
    required this.byUid,
    required this.byName,
    required this.createdAt,
    required this.status,
    required this.devMemo,
  });

  final String id;
  final FeedbackType type;
  final String body;
  final String appVersion;

  /// 送った人
  final String byUid;
  final String byName;

  /// 送った日時（保存中は null）
  final DateTime? createdAt;

  final FeedbackStatus status;

  /// 開発者からの一言メモ（空なら未記入）
  final String devMemo;
}
