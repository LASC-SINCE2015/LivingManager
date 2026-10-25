import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../items/data/categories_repository.dart';
import '../../items/data/items_repository.dart';
import '../../items/domain/category.dart';
import '../../items/domain/category_name_rules.dart';
import '../../items/domain/item.dart';
import '../../items/presentation/items_providers.dart';

/// カテゴリ管理画面（設定 → カテゴリ管理）
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) async {
    final name = await showTextInputDialog(
      context,
      title: 'カテゴリを追加',
      label: 'カテゴリ名',
      maxLength: maxCategoryNameLength,
      validator: (value) => validateCategoryName(value, categories),
    );
    if (name == null || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(itemsRepositoryProvider).addCategory(name, categories),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> categories,
  ) async {
    final name = await showTextInputDialog(
      context,
      title: 'カテゴリ名を変更',
      label: 'カテゴリ名',
      initialValue: category.name,
      maxLength: maxCategoryNameLength,
      validator: (value) =>
          validateCategoryName(value, categories, excludeId: category.id),
    );
    if (name == null || name == category.name || !context.mounted) return;
    await runWithErrorMessage(
      context,
      () => ref.read(categoriesRepositoryProvider).rename(category.id, name),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
    int itemCount,
  ) async {
    final ok = await showConfirmDialog(
      context,
      message:
          '『${category.name}』を削除しますか？ '
          'このカテゴリのアイテム $itemCount 件は『その他』に移動します',
      okLabel: '削除',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await runWithErrorMessage(context, () async {
      await ref.read(categoriesRepositoryProvider).delete(category.id);
      return true;
    });
    if (done == true) showMessage(messenger, '『${category.name}』を削除しました');
  }

  /// 並べ替え（「その他」は常に一番下で動かせない）
  void _reorder(
    BuildContext context,
    WidgetRef ref,
    List<Category> movable,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex >= movable.length) return;
    // 「その他」より下には置けない
    final target = newIndex.clamp(0, movable.length - 1);
    if (target == oldIndex) return;
    final ids = movable.map((c) => c.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(target, moved);
    runWithErrorMessage(
      context,
      () => ref.read(categoriesRepositoryProvider).reorder(ids),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final itemsAsync = ref.watch(itemsProvider);
    final categories = categoriesAsync.value;
    final items = itemsAsync.value;

    Widget body;
    if (categoriesAsync.hasError || itemsAsync.hasError) {
      body = const Center(child: Text('読み込めませんでした。通信状態を確認してください'));
    } else if (categories == null || items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final counts = _countItems(categories, items);
      final movable = categories
          .where((c) => c.id != Category.otherId)
          .toList();
      final other = categories
          .where((c) => c.id == Category.otherId)
          .firstOrNull;

      body = ReorderableListView(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 88),
        onReorderItem: (oldIndex, newIndex) =>
            _reorder(context, ref, movable, oldIndex, newIndex),
        children: [
          for (final (index, category) in movable.indexed)
            _CategoryTile(
              key: ValueKey(category.id),
              category: category,
              itemCount: counts[category.id] ?? 0,
              dragIndex: index,
              onTap: () => _rename(context, ref, category, categories),
              onDelete: () =>
                  _delete(context, ref, category, counts[category.id] ?? 0),
            ),
          if (other != null)
            _CategoryTile(
              key: ValueKey(other.id),
              category: other,
              itemCount: counts[other.id] ?? 0,
              onTap: () => _rename(context, ref, other, categories),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ管理')),
      floatingActionButton: categories == null
          ? null
          : FloatingActionButton(
              tooltip: 'カテゴリを追加',
              onPressed: () => _add(context, ref, categories),
              child: const Icon(Icons.add),
            ),
      body: body,
    );
  }

  /// カテゴリごとのアイテム数（存在しないカテゴリのアイテムは「その他」に数える）
  static Map<String, int> _countItems(
    List<Category> categories,
    List<Item> items,
  ) {
    final known = categories.map((c) => c.id).toSet();
    final counts = <String, int>{};
    for (final item in items) {
      final id = known.contains(item.categoryId)
          ? item.categoryId
          : Category.otherId;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.itemCount,
    required this.onTap,
    this.dragIndex,
    this.onDelete,
  });

  final Category category;
  final int itemCount;
  final VoidCallback onTap;

  /// 並べ替えのつまみの位置。null なら並べ替えできない（「その他」）
  final int? dragIndex;

  /// null なら削除できない（「その他」）
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isOther = category.id == Category.otherId;
    return ListTile(
      title: Text(category.name),
      subtitle: Text(
        isOther ? 'アイテム $itemCount 件・常に一番下（削除不可）' : 'アイテム $itemCount 件',
      ),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'メニュー',
              onSelected: (_) => onDelete!(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
