import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/history_rules.dart';
import 'history_providers.dart';

/// アイテム編集シートに出す、そのアイテムの購入履歴（直近 1 年）
class ItemHistorySection extends ConsumerWidget {
  const ItemHistorySection({super.key, required this.itemId});

  /// 一度に表示する記録の数
  static const _maxShown = 5;

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final history = ref.watch(itemHistoryProvider(itemId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('購入履歴（直近1年）', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        switch (history) {
          AsyncValue(hasError: true) => Text(
            '購入履歴を読み込めませんでした',
            style: mutedStyle,
          ),
          AsyncValue(:final value?) when value.isEmpty => Text(
            'まだ記録がありません（購入完了にすると記録されます）',
            style: mutedStyle,
          ),
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${value.length}回購入', style: theme.textTheme.bodyMedium),
              for (final record in value.take(_maxShown))
                Text(
                  '・${formatPurchaseDate(record.purchasedAt)} ${record.byName}',
                  style: mutedStyle,
                ),
              if (value.length > _maxShown)
                Text('ほか${value.length - _maxShown}件', style: mutedStyle),
            ],
          ),
          _ => Text('読み込み中…', style: mutedStyle),
        },
      ],
    );
  }
}
