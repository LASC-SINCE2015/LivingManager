import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_normalizer.dart';
import '../domain/history_rules.dart';
import '../domain/purchase_record.dart';
import 'history_providers.dart';

/// 購入履歴の画面（設定 → 購入履歴）
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// アイテム名で絞り込む文字列
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(allHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('購入履歴')),
      body: switch (history) {
        AsyncValue(hasError: true) => const Center(
          child: Text('読み込めませんでした。通信状態を確認してください'),
        ),
        AsyncValue(:final value?) => _HistoryList(
          records: _filter(value),
          searching: normalizeForCompare(_query).isNotEmpty,
          onQueryChanged: (value) => setState(() => _query = value),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  List<PurchaseRecord> _filter(List<PurchaseRecord> records) {
    final query = normalizeForCompare(_query);
    if (query.isEmpty) return records;
    return [
      for (final record in records)
        if (normalizeForCompare(record.itemName).contains(query)) record,
    ];
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.records,
    required this.searching,
    required this.onQueryChanged,
  });

  final List<PurchaseRecord> records;
  final bool searching;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        TextField(
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'アイテム名で検索',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text('購入完了にした記録です。1年を過ぎた記録は自動で消えます。', style: mutedStyle),
        ),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              searching ? '該当する記録がありません' : 'まだ記録がありません',
              textAlign: TextAlign.center,
            ),
          ),
        for (final record in records)
          Card(
            child: ListTile(
              dense: true,
              title: Text(record.itemName),
              subtitle: Text(
                '${formatPurchaseDate(record.purchasedAt)}・${record.byName}',
              ),
            ),
          ),
      ],
    );
  }
}
