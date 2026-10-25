import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_normalizer.dart';
import '../domain/category.dart';
import '../domain/item.dart';
import 'item_card.dart';
import 'item_edit_sheet.dart';
import 'items_providers.dart';

/// 在庫一覧画面（タブ1）
class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('在庫一覧')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'アイテムを追加',
        onPressed: () => showItemEditSheet(context),
        child: const Icon(Icons.add),
      ),
      body: switch ((categories.value, items.value)) {
        _ when categories.hasError || items.hasError => const Center(
          child: Text('読み込めませんでした。通信状態を確認してください'),
        ),
        (final List<Category> cats, final List<Item> list) => _StockList(
          categories: cats,
          items: list,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({required this.categories, required this.items});

  final List<Category> categories;
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '右下の＋ボタンからアイテムを追加してください',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // カテゴリが見つからないアイテムは「その他」に入れる
    final knownIds = categories.map((c) => c.id).toSet();
    final byCategory = <String, List<Item>>{};
    for (final item in items) {
      final id = knownIds.contains(item.categoryId)
          ? item.categoryId
          : Category.otherId;
      byCategory.putIfAbsent(id, () => []).add(item);
    }
    // ステータスが変わっても位置が動かないよう、名前の順に並べる
    for (final list in byCategory.values) {
      list.sort(
        (a, b) => normalizeForCompare(a.name).compareTo(normalizeForCompare(b.name)),
      );
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              '${category.name}（${byCategory[category.id]?.length ?? 0}）',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final item in byCategory[category.id] ?? const <Item>[])
            ItemCard(key: ValueKey(item.id), item: item),
        ],
      ],
    );
  }
}
