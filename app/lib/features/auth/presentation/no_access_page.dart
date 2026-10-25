import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import 'auth_providers.dart';

/// アクセス権限エラー画面（表示した時点で自動的にサインアウトする）
class NoAccessPage extends ConsumerStatefulWidget {
  const NoAccessPage({super.key});

  @override
  ConsumerState<NoAccessPage> createState() => _NoAccessPageState();
}

class _NoAccessPageState extends ConsumerState<NoAccessPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = ref.read(authRepositoryProvider);
      if (repository.currentUser != null) repository.signOut();
    });
  }

  void _backToLogin() {
    ref.read(deniedEmailProvider.notifier).set(null);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
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
                OutlinedButton(
                  onPressed: _backToLogin,
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
