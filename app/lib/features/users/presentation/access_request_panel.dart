import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/snack_bars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/users_repository.dart';
import 'users_providers.dart';

/// アクセス権限エラー画面に出す「管理者に追加を依頼する」の部分。
///
/// 依頼前は依頼ボタン、依頼後は「依頼済み」と、承認されたかを確かめるボタンを出す。
class AccessRequestPanel extends ConsumerStatefulWidget {
  const AccessRequestPanel({super.key});

  @override
  ConsumerState<AccessRequestPanel> createState() => _AccessRequestPanelState();
}

class _AccessRequestPanelState extends ConsumerState<AccessRequestPanel> {
  bool _busy = false;

  Future<void> _request() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(usersRepositoryProvider).requestAccess(user);
      if (mounted) ref.invalidate(myAccessRequestProvider);
      showMessage(messenger, '管理者に依頼しました');
    } catch (_) {
      showMessage(messenger, '依頼できませんでした。通信状態を確認してください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 承認されたかを確かめる（承認されていれば在庫一覧へ切り替わる）
  void _recheck() {
    ref.invalidate(accessCheckProvider);
    ref.invalidate(myAccessRequestProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserProvider) == null) return const SizedBox.shrink();
    final requested = ref.watch(myAccessRequestProvider);
    final theme = Theme.of(context);

    if (requested.isLoading) return const LinearProgressIndicator();

    // 読み込めなかったときも依頼ボタンを出す（すでに依頼済みなら保存に失敗する）
    if (requested.value != true) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _request,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('管理者に追加を依頼する'),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '管理者に追加を依頼済みです。\n承認されたら「もう一度確認する」を押してください。',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _recheck,
            icon: const Icon(Icons.refresh),
            label: const Text('もう一度確認する'),
          ),
        ),
      ],
    );
  }
}
