import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/access_status.dart';
import 'auth_providers.dart';

/// ログイン状態の確認中・利用の準備中に表示する画面
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(accessStatusProvider);
    if (status != AccessStatus.error) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 16),
              const Text('接続できませんでした'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.invalidate(accessCheckProvider),
                child: const Text('再試行'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('ログアウト'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
