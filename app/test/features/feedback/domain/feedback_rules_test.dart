import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/feedback/domain/feedback_rules.dart';
import 'package:living_manager/features/feedback/domain/user_feedback.dart';

UserFeedback _feedback(
  String id, {
  DateTime? createdAt,
  FeedbackStatus status = FeedbackStatus.open,
  FeedbackType type = FeedbackType.request,
}) => UserFeedback(
  id: id,
  type: type,
  body: '本文',
  appVersion: '1.0.0+1',
  byUid: 'u1',
  byName: 'テスト',
  createdAt: createdAt,
  status: status,
  devMemo: '',
);

void main() {
  group('validateFeedbackBody', () {
    test('空・空白だけはエラー', () {
      expect(validateFeedbackBody(''), isNotNull);
      expect(validateFeedbackBody('  　'), isNotNull);
    });

    test('1000 文字までは OK、超えるとエラー', () {
      expect(validateFeedbackBody('あ' * feedbackBodyMaxLength), isNull);
      expect(validateFeedbackBody('あ' * (feedbackBodyMaxLength + 1)), isNotNull);
    });
  });

  group('validateDevMemo', () {
    test('空は OK、500 文字を超えるとエラー', () {
      expect(validateDevMemo(''), isNull);
      expect(validateDevMemo('あ' * (devMemoMaxLength + 1)), isNotNull);
    });
  });

  group('enum の変換', () {
    test('保存値から戻せる', () {
      expect(FeedbackType.fromValue('bug'), FeedbackType.bug);
      expect(FeedbackStatus.fromValue('in_progress'), FeedbackStatus.inProgress);
      expect(FeedbackStatus.fromValue('wont_fix'), FeedbackStatus.wontFix);
    });

    test('知らない値は既定値になる', () {
      expect(FeedbackType.fromValue('x'), FeedbackType.other);
      expect(FeedbackStatus.fromValue(null), FeedbackStatus.open);
    });
  });

  group('sortNewestFirst', () {
    test('新しい順。日時が未確定のものは一番上', () {
      final sorted = sortNewestFirst([
        _feedback('old', createdAt: DateTime(2026, 1, 1)),
        _feedback('pending'),
        _feedback('new', createdAt: DateTime(2026, 2, 1)),
      ]);
      expect(sorted.map((f) => f.id), ['pending', 'new', 'old']);
    });
  });

  group('filterFeedback / countByStatus', () {
    final list = [
      _feedback('a', status: FeedbackStatus.open, type: FeedbackType.bug),
      _feedback('b', status: FeedbackStatus.done, type: FeedbackType.bug),
      _feedback('c', status: FeedbackStatus.open, type: FeedbackType.request),
    ];

    test('状態と種類の両方で絞り込める（null はすべて）', () {
      expect(filterFeedback(list).length, 3);
      expect(
        filterFeedback(list, status: FeedbackStatus.open, type: FeedbackType.bug)
            .map((f) => f.id),
        ['a'],
      );
    });

    test('状態ごとの件数（0 件の状態も含む）', () {
      final counts = countByStatus(list);
      expect(counts[FeedbackStatus.open], 2);
      expect(counts[FeedbackStatus.done], 1);
      expect(counts[FeedbackStatus.wontFix], 0);
    });
  });
}
