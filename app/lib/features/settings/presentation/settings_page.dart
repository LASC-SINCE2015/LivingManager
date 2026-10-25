import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/member_repository.dart';
import '../../auth/presentation/auth_providers.dart';

/// 設定画面（タブ3）
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String current,
  ) async {
    final name = await showTextInputDialog(
      context,
      title: '表示名を変更',
      label: '表示名',
      initialValue: current,
      maxLength: MemberRepository.maxNameLength,
      validator: (value) {
        if (value.isEmpty) return '表示名を入力してください';
        if (value.length > MemberRepository.maxNameLength) {
          return '${MemberRepository.maxNameLength}文字以内で入力してください';
        }
        return null;
      },
    );
    if (name == null || name == current || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(memberRepositoryProvider).updateDisplayName(uid, name),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      message: 'ログアウトしますか？',
      okLabel: 'ログアウト',
    );
    if (!ok) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final actor = ref.watch(actorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('表示名'),
            subtitle: Text(actor?.displayName ?? ''),
            trailing: const Icon(Icons.edit),
            onTap: actor == null
                ? null
                : () => _editDisplayName(
                    context,
                    ref,
                    actor.uid,
                    actor.displayName,
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('ログイン中のアカウント'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}
