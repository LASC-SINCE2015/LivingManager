import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../users/presentation/access_request_panel.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';

/// アクセス権限エラー画面。
///
/// 管理者に追加を依頼できるよう、ログインしたままにしておく
/// （「別のアカウントでログイン」でサインアウトする）。
class NoAccessPage extends ConsumerWidget {
  const NoAccessPage({super.key});

  Future<void> _backToLogin(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(authRepositoryProvider);
    if (repository.currentUser != null) await repository.signOut();
    ref.read(deniedEmailProvider.notifier).set(null);
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final email = ref.watch(deniedEmailProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('アクセス権限がありません', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (email != null) ...[
                  Text(email, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'このアカウントは利用を許可されていません。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const AccessRequestPanel(),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _backToLogin(context, ref),
                  child: const Text('別のアカウントでログイン'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
