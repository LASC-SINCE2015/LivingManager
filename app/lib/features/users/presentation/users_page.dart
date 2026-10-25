import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/users_repository.dart';
import '../domain/access_request.dart';
import '../domain/allowed_user.dart';
import '../domain/user_rules.dart';
import 'users_providers.dart';

/// ユーザー管理（開発者用）。追加の依頼の承認・却下と、許可済みのアカウントの一覧。
/// 下部のタブを出さない独立したページ
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloper = ref.watch(isDeveloperProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '戻る',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('ユーザー管理（開発者用）'),
      ),
      body: isDeveloper.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _NoPermission(),
        // 開発者でなければ一覧は読み込まない
        data: (ok) => ok ? const _UsersBody() : const _NoPermission(),
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

class _UsersBody extends ConsumerWidget {
  const _UsersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(accessRequestsProvider);
    final users = ref.watch(allowedUsersProvider);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: textTheme.titleMedium),
    );

    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(text)),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...requests.when(
              loading: () => [
                heading('追加の依頼'),
                const Center(child: CircularProgressIndicator()),
              ],
              error: (_, _) => [heading('追加の依頼'), message('読み込めませんでした')],
              data: (list) => [
                heading('追加の依頼（${list.length}）'),
                if (list.isEmpty)
                  message('依頼はありません')
                else
                  for (final request in list) _RequestCard(request: request),
              ],
            ),
            ...users.when(
              loading: () => [
                heading('現在のユーザー'),
                const Center(child: CircularProgressIndicator()),
              ],
              error: (_, _) => [heading('現在のユーザー'), message('読み込めませんでした')],
              data: (list) => [
                heading('現在のユーザー（${list.length}）'),
                Card(
                  child: Column(
                    children: [
                      for (final user in list) _AllowedUserTile(user: user),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                'メモ・開発者の変更や、ユーザーの削除は Firebase コンソールから行います。',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 追加の依頼 1 件のカード（承認・却下）
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final AccessRequest request;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ApproveResult>(
      context: context,
      builder: (_) => _ApproveDialog(request: request),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await runWithErrorMessage(context, () async {
      await ref
          .read(usersRepositoryProvider)
          .approve(request.email, memo: result.memo, admin: result.admin);
      return true;
    });
    if (done == true) showMessage(messenger, '${request.email} を追加しました');
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      message: '${request.email} の依頼を却下しますか？\n（依頼は削除され、本人はもう一度依頼できます）',
      okLabel: '却下',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(usersRepositoryProvider).reject(request.email),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(request.email, style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              [
                if (request.displayName.isNotEmpty) request.displayName,
                '依頼日時 ${formatDateTime(request.requestedAt)}',
              ].join('・'),
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('却下'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.check),
                  label: const Text('承認'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 許可済みのアカウント 1 件
class _AllowedUserTile extends StatelessWidget {
  const _AllowedUserTile({required this.user});

  final AllowedUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        user.admin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
      ),
      title: Text(user.email),
      subtitle: user.memo.isEmpty ? null : Text(user.memo),
      trailing: user.admin ? const Chip(label: Text('開発者')) : null,
    );
  }
}

/// 承認ダイアログで決めた値
class _ApproveResult {
  const _ApproveResult({required this.memo, required this.admin});

  final String memo;
  final bool admin;
}

/// 承認ダイアログ。メモ（初期値は依頼したアカウントの名前）と、開発者にするかを決める
class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.request});

  final AccessRequest request;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _memo = TextEditingController(
    text: initialMemoFor(widget.request),
  );
  bool _admin = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ApproveResult(memo: _memo.text.trim(), admin: _admin),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('依頼を承認'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.request.email),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memo,
              autofocus: true,
              maxLength: userMemoMaxLength,
              decoration: const InputDecoration(
                labelText: 'メモ',
                helperText: '誰のアカウントか（例: 父）',
              ),
              validator: (value) => validateUserMemo((value ?? '').trim()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開発者にする'),
              subtitle: const Text('改善意見の一覧・ユーザー管理を使える'),
              value: _admin,
              onChanged: (value) => setState(() => _admin = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('承認')),
      ],
    );
  }
}
