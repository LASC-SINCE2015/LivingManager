import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../settings/presentation/settings_page.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_rules.dart';
import '../domain/user_feedback.dart';
import 'feedback_providers.dart';

/// 改善意見を送る画面（設定 → 改善意見を送る）
class SendFeedbackPage extends ConsumerStatefulWidget {
  const SendFeedbackPage({super.key});

  @override
  ConsumerState<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends ConsumerState<SendFeedbackPage> {
  final _bodyController = TextEditingController();
  FeedbackType _type = FeedbackType.request;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // 本文の有無で送信ボタンの押せる・押せないを切り替える
    _bodyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    final error = validateFeedbackBody(body);
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      showMessage(messenger, error);
      return;
    }
    final actor = ref.read(actorProvider);
    if (actor == null) return;

    setState(() => _sending = true);
    try {
      final version = await ref
          .read(appVersionProvider.future)
          .catchError((_) => '不明');
      await ref
          .read(feedbackRepositoryProvider)
          .submit(type: _type, body: body, appVersion: version, actor: actor);
      if (!mounted) return;
      _bodyController.clear();
      setState(() => _type = FeedbackType.request);
      showMessage(messenger, '送信しました。ありがとうございます');
    } catch (_) {
      showMessage(messenger, '送信できませんでした。通信状態を確認してください');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myFeedbackProvider);
    final canSend = _bodyController.text.trim().isNotEmpty && !_sending;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('改善意見を送る')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '使ってみて気になったこと・こうなったら嬉しいことを送ってください。'
            '開発者だけが読みます。',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FeedbackType>(
              segments: [
                for (final type in FeedbackType.values)
                  ButtonSegment(value: type, label: Text(type.label)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: _sending
                  ? null
                  : (selected) => setState(() => _type = selected.first),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            maxLength: feedbackBodyMaxLength,
            decoration: const InputDecoration(
              labelText: '本文',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: canSend ? _send : null,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('送信'),
            ),
          ),
          const Divider(height: 32),
          Text('送った意見', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          mine.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text('読み込めませんでした'),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('まだ送った意見はありません'),
                  )
                : Column(
                    children: [
                      for (final feedback in list)
                        _MyFeedbackTile(feedback: feedback),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 自分が送った意見の 1 行。本文は 3 行まで表示し、タップで全文を表示する
class _MyFeedbackTile extends StatefulWidget {
  const _MyFeedbackTile({required this.feedback});

  final UserFeedback feedback;

  @override
  State<_MyFeedbackTile> createState() => _MyFeedbackTileState();
}

class _MyFeedbackTileState extends State<_MyFeedbackTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(f.type.label, style: textTheme.labelLarge),
                  const Spacer(),
                  Text(
                    f.status.label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                f.body,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                formatDateTime(f.createdAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (f.devMemo.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DevMemo(memo: f.devMemo),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 開発者からのメモ
class _DevMemo extends StatelessWidget {
  const _DevMemo({required this.memo});

  final String memo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('開発者より: $memo'),
    );
  }
}
