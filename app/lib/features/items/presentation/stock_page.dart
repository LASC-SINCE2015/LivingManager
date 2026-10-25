import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_normalizer.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/data/member_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/category.dart';
import '../domain/item.dart';
import '../domain/item_order.dart';
import 'item_card.dart';
import 'item_edit_sheet.dart';
import 'items_providers.dart';

/// 在庫一覧画面（タブ1）
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _searchController = TextEditingController();

  /// 検索文字列
  String _query = '';

  /// 絞り込み中のカテゴリ（null は「すべて」）
  String? _filterCategoryId;

  /// 並べ替えモード中か
  bool _reordering = false;

  /// 保存中の並び順（保存が終わるまで、先に画面に反映しておく）
  final Map<String, List<String>> _pendingOrder = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ほかのタブに切り替えたら（このタブが非表示になったら）通常の表示に戻す
    if (_reordering && !TickerMode.valuesOf(context).enabled) {
      _reordering = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final items = ref.watch(itemsProvider);
    final myOrder = ref.watch(myItemOrderProvider).value ?? const {};

    final cats = categories.value;
    // 絞り込み中のカテゴリが削除されたら「すべて」に戻す
    final filterCategoryId =
        cats != null && cats.any((c) => c.id == _filterCategoryId)
        ? _filterCategoryId
        : null;
    List<String>? orderOf(String categoryId) =>
        _pendingOrder[categoryId] ?? myOrder[categoryId];

    return Scaffold(
      appBar: _reordering
          ? AppBar(
              automaticallyImplyLeading: false,
              title: const Text('並べ替え中'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _reordering = false),
                  child: const Text('完了'),
                ),
              ],
            )
          : AppBar(
              title: const Text('在庫一覧'),
              actions: [
                IconButton(
                  tooltip: '並べ替え',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _startReordering,
                ),
              ],
            ),
      floatingActionButton: _reordering
          ? null
          : FloatingActionButton(
              tooltip: 'アイテムを追加',
              onPressed: () => showItemEditSheet(
                context,
                initialCategoryId: filterCategoryId,
              ),
              child: const Icon(Icons.add),
            ),
      body: switch ((cats, items.value)) {
        _ when categories.hasError || items.hasError => const Center(
          child: Text('読み込めませんでした。通信状態を確認してください'),
        ),
        (List<Category> _, final List<Item> list) when list.isEmpty =>
          const _EmptyMessage('右下の＋ボタンからアイテムを追加してください'),
        (final List<Category> cats, final List<Item> list) when _reordering =>
          _ReorderView(
            categories: cats,
            byCategory: groupByCategory(cats, list),
            orderOf: orderOf,
            onReorder: _saveOrder,
          ),
        (final List<Category> cats, final List<Item> list) => Column(
          children: [
            _SearchArea(
              controller: _searchController,
              categories: cats,
              selectedCategoryId: filterCategoryId,
              onQueryChanged: (value) => setState(() => _query = value),
              onCategorySelected: (id) =>
                  setState(() => _filterCategoryId = id),
            ),
            Expanded(
              child: _StockList(
                categories: cats,
                byCategory: groupByCategory(
                  cats,
                  _filter(cats, list, filterCategoryId),
                ),
                orderOf: orderOf,
                filtering:
                    filterCategoryId != null ||
                    normalizeForCompare(_query).isNotEmpty,
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// 検索文字列とカテゴリで絞り込む（両方の条件に合うもの）
  List<Item> _filter(
    List<Category> categories,
    List<Item> items,
    String? categoryId,
  ) {
    final query = normalizeForCompare(_query);
    final knownIds = categories.map((c) => c.id).toSet();
    return [
      for (final item in items)
        if ((categoryId == null ||
                categoryKeyOf(item, knownIds) == categoryId) &&
            (query.isEmpty ||
                normalizeForCompare(item.name).contains(query) ||
                normalizeForCompare(item.memo).contains(query)))
          item,
    ];
  }

  /// 並べ替えモードにする（検索・絞り込みは解除する）
  void _startReordering() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _query = '';
      _filterCategoryId = null;
      _reordering = true;
    });
  }

  /// カテゴリ内でアイテムを動かし、その並び順を保存する
  Future<void> _saveOrder(
    String categoryId,
    List<Item> sorted,
    int oldIndex,
    int newIndex,
  ) async {
    final uid = ref.read(actorProvider)?.uid;
    if (uid == null) return;
    final ids = moveItem(sorted, oldIndex, newIndex);
    setState(() => _pendingOrder[categoryId] = ids);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(memberRepositoryProvider)
          .saveCategoryOrder(uid, categoryId, ids);
    } catch (_) {
      showMessage(messenger, '並び順を保存できませんでした。通信状態を確認してください');
    } finally {
      // 失敗した場合は、保存済みの並び順に戻る
      if (mounted) setState(() => _pendingOrder.remove(categoryId));
    }
  }
}

/// アイテムが入るカテゴリ（カテゴリが見つからないアイテムは「その他」）
String categoryKeyOf(Item item, Set<String> knownIds) =>
    knownIds.contains(item.categoryId) ? item.categoryId : Category.otherId;

/// アイテムをカテゴリごとに分ける
Map<String, List<Item>> groupByCategory(
  List<Category> categories,
  List<Item> items,
) {
  final knownIds = categories.map((c) => c.id).toSet();
  final byCategory = <String, List<Item>>{};
  for (final item in items) {
    byCategory.putIfAbsent(categoryKeyOf(item, knownIds), () => []).add(item);
  }
  return byCategory;
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// 検索バーとカテゴリフィルター
class _SearchArea extends StatelessWidget {
  const _SearchArea({
    required this.controller,
    required this.categories,
    required this.selectedCategoryId,
    required this.onQueryChanged,
    required this.onCategorySelected,
  });

  final TextEditingController controller;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'アイテム名・メモで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '検索をクリア',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      ),
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              ChoiceChip(
                label: const Text('すべて'),
                selected: selectedCategoryId == null,
                onSelected: (_) => onCategorySelected(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category.name),
                  selected: selectedCategoryId == category.id,
                  onSelected: (selected) =>
                      onCategorySelected(selected ? category.id : null),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 通常の一覧（カテゴリ別のセクション）
class _StockList extends StatelessWidget {
  const _StockList({
    required this.categories,
    required this.byCategory,
    required this.orderOf,
    required this.filtering,
  });

  final List<Category> categories;
  final Map<String, List<Item>> byCategory;
  final List<String>? Function(String categoryId) orderOf;

  /// 検索・絞り込み中か（0 件のカテゴリを出さない）
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    if (filtering && byCategory.isEmpty) {
      return const _EmptyMessage('該当するアイテムがありません');
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: [
        for (final category in categories)
          if (!filtering || byCategory.containsKey(category.id)) ...[
            _SectionHeader(
              title:
                  '${category.name}（${byCategory[category.id]?.length ?? 0}）',
              theme: theme,
            ),
            // ステータスが変わっても位置が動かないよう、自分の並び順で並べる
            for (final item in sortByMyOrder(
              byCategory[category.id] ?? const <Item>[],
              orderOf(category.id),
            ))
              ItemCard(key: ValueKey(item.id), item: item),
          ],
      ],
    );
  }
}

/// 並べ替えモードの一覧（カテゴリごとに、同じカテゴリの中だけで並べ替える）
class _ReorderView extends StatelessWidget {
  const _ReorderView({
    required this.categories,
    required this.byCategory,
    required this.orderOf,
    required this.onReorder,
  });

  final List<Category> categories;
  final Map<String, List<Item>> byCategory;
  final List<String>? Function(String categoryId) orderOf;
  final void Function(
    String categoryId,
    List<Item> sorted,
    int oldIndex,
    int newIndex,
  )
  onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        for (final category in categories)
          if (byCategory[category.id] case final items?) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: '${category.name}（${items.length}）',
                  theme: theme,
                ),
              ),
            ),
            _buildCategoryList(
              category.id,
              sortByMyOrder(items, orderOf(category.id)),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCategoryList(String categoryId, List<Item> sorted) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverReorderableList(
        itemCount: sorted.length,
        onReorderItem: (oldIndex, newIndex) =>
            onReorder(categoryId, sorted, oldIndex, newIndex),
        itemBuilder: (context, index) {
          final item = sorted[index];
          return Card(
            key: ValueKey(item.id),
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              title: Text(item.name),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
