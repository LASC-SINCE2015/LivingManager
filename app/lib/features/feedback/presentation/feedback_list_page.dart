import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_rules.dart';
import '../domain/user_feedback.dart';
import 'feedback_providers.dart';

/// 改善意見の一覧（開発者用）。下部のタブを出さない独立したページ
class FeedbackListPage extends ConsumerWidget {
  const FeedbackListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloper = ref.watch(isDeveloperProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '戻る',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/stock'),
        ),
        title: const Text('改善意見の一覧（開発者用）'),
      ),
      body: isDeveloper.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _NoPermission(),
        // 開発者でなければ一覧は読み込まない
        data: (ok) => ok ? const _FeedbackList() : const _NoPermission(),
      ),
    );
  }
}

/// 開発者でないときの表示
class _NoPermission extends StatelessWidget {
  const _NoPermission();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('このページを見る権限がありません'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/stock'),
            child: const Text('在庫一覧へ戻る'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackList extends ConsumerStatefulWidget {
  const _FeedbackList();

  @override
  ConsumerState<_FeedbackList> createState() => _FeedbackListState();
}

class _FeedbackListState extends ConsumerState<_FeedbackList> {
  /// 状態の絞り込み（null は「すべて」）
  FeedbackStatus? _status = FeedbackStatus.open;

  /// 種類の絞り込み（null は「すべて」）
  FeedbackType? _type;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allFeedbackProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: all.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('読み込めませんでした')),
          data: (list) {
            final byType = filterFeedback(list, type: _type);
            final counts = countByStatus(byType);
            final shown = filterFeedback(byType, status: _status);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: Text('すべて（${byType.length}）'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                    ),
                    for (final status in FeedbackStatus.values)
                      ChoiceChip(
                        label: Text('${status.label}（${counts[status]}）'),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('すべて'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    for (final type in FeedbackType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('該当する意見はありません')),
                  )
                else
                  for (final feedback in shown)
                    _FeedbackCard(feedback: feedback),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _CardMenu { delete }

/// 改善意見 1 件のカード（状態・メモの変更、削除）
class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({required this.feedback});

  final UserFeedback feedback;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    FeedbackStatus status,
  ) async {
    if (status == feedback.status) return;
    await runWithErrorMessage(
      context,
      () => ref
          .read(feedbackRepositoryProvider)
          .updateStatus(feedback.id, status),
    );
  }

  Future<void> _editMemo(BuildContext context, WidgetRef ref) async {
    final memo = await showDialog<String>(
      context: context,
      builder: (_) => _MemoDialog(initialValue: feedback.devMemo),
    );
    if (memo == null || memo == feedback.devMemo || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(feedbackRepositoryProvider).updateMemo(feedback.id, memo),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      message: 'この意見を削除しますか？',
      okLabel: '削除',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(feedbackRepositoryProvider).delete(feedback.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(feedback.type.label, style: textTheme.labelLarge),
                const Spacer(),
                DropdownButton<FeedbackStatus>(
                  value: feedback.status,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final status in FeedbackStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (status) {
                    if (status != null) _changeStatus(context, ref, status);
                  },
                ),
                PopupMenuButton<_CardMenu>(
                  tooltip: 'メニュー',
                  onSelected: (_) => _delete(context, ref),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _CardMenu.delete, child: Text('削除')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectableText(feedback.body),
            ),
            const SizedBox(height: 8),
            Text(
              '${feedback.byName}・${formatDateTime(feedback.createdAt)}'
              '・バージョン ${feedback.appVersion}',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (feedback.devMemo.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('メモ: ${feedback.devMemo}'),
              ),
            TextButton.icon(
              onPressed: () => _editMemo(context, ref),
              icon: const Icon(Icons.edit_note),
              label: const Text('メモを編集'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 開発者メモの編集ダイアログ。保存されたら前後の空白を除いた値を返す
class _MemoDialog extends StatefulWidget {
  const _MemoDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<_MemoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('メモを編集'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: devMemoMaxLength,
          decoration: const InputDecoration(
            labelText: 'メモ',
            helperText: 'メモは送った本人にも表示されます',
            alignLabelWithHint: true,
          ),
          validator: (value) => validateDevMemo(value ?? ''),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
