import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_normalizer.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../auth/data/member_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/category.dart';
import '../domain/item.dart';
import '../domain/item_order.dart';
import '../domain/stock_status.dart';
import 'item_card.dart';
import 'item_edit_sheet.dart';
import 'items_providers.dart';
import 'status_colors.dart';
import 'status_selector.dart';

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

  /// 保存中の「閉じているカテゴリ」（保存が終わるまで、先に画面に反映しておく）
  Set<String>? _pendingHidden;

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
    final hidden =
        _pendingHidden ??
        ref.watch(myHiddenCategoriesProvider).value ??
        const <String>{};

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
                if (cats != null && cats.isNotEmpty)
                  _ToggleAllButton(
                    allHidden: cats.every((c) => hidden.contains(c.id)),
                    onPressed: (hideAll) => _saveHidden(
                      hideAll ? {for (final c in cats) c.id} : const {},
                    ),
                  ),
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
              counts: countByStatus(list),
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
                hidden: hidden,
                onToggleCategory: (id) => _saveHidden(
                  hidden.contains(id)
                      ? ({...hidden}..remove(id))
                      : {...hidden, id},
                ),
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

  /// 閉じているカテゴリを保存する
  Future<void> _saveHidden(Set<String> next) async {
    final uid = ref.read(actorProvider)?.uid;
    if (uid == null) return;
    setState(() => _pendingHidden = next);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(memberRepositoryProvider).saveHiddenCategories(uid, next);
    } catch (_) {
      showMessage(messenger, '表示の切り替えを保存できませんでした。通信状態を確認してください');
    } finally {
      // 保存が終わったら（失敗した場合も）保存済みの状態に戻す。続けて押された場合は新しいほうを残す
      if (mounted && identical(_pendingHidden, next)) {
        setState(() => _pendingHidden = null);
      }
    }
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

/// ステータスごとの件数
Map<StockStatus, int> countByStatus(List<Item> items) {
  final counts = <StockStatus, int>{};
  for (final item in items) {
    counts.update(item.status, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

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
    required this.counts,
    required this.selectedCategoryId,
    required this.onQueryChanged,
    required this.onCategorySelected,
  });

  final TextEditingController controller;
  final List<Category> categories;

  /// 全アイテムのステータスごとの件数（凡例に出す）
  final Map<StockStatus, int> counts;
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
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusLegend(counts: counts),
          ),
        ),
      ],
    );
  }
}

/// すべてのカテゴリを開く・閉じるボタン
class _ToggleAllButton extends StatelessWidget {
  const _ToggleAllButton({required this.allHidden, required this.onPressed});

  final bool allHidden;

  /// true ならすべて閉じる、false ならすべて開く
  final ValueChanged<bool> onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: allHidden ? 'すべて開く' : 'すべて閉じる',
      icon: Icon(allHidden ? Icons.unfold_more : Icons.unfold_less),
      onPressed: () => onPressed(!allHidden),
    );
  }
}

/// 通常の一覧（カテゴリ別のセクション）
class _StockList extends StatelessWidget {
  const _StockList({
    required this.categories,
    required this.byCategory,
    required this.orderOf,
    required this.hidden,
    required this.onToggleCategory,
    required this.filtering,
  });

  final List<Category> categories;
  final Map<String, List<Item>> byCategory;
  final List<String>? Function(String categoryId) orderOf;

  /// 閉じているカテゴリの ID
  final Set<String> hidden;
  final ValueChanged<String> onToggleCategory;

  /// 検索・絞り込み中か（0 件のカテゴリを出さない。閉じているカテゴリも開いて見せる）
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    if (filtering && byCategory.isEmpty) {
      return const _EmptyMessage('該当するアイテムがありません');
    }

    bool expanded(String categoryId) =>
        filtering || !hidden.contains(categoryId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: [
        for (final category in categories)
          if (!filtering || byCategory.containsKey(category.id)) ...[
            _SectionHeader(
              name: category.name,
              items: byCategory[category.id] ?? const <Item>[],
              expanded: expanded(category.id),
              onTap: filtering ? null : () => onToggleCategory(category.id),
            ),
            if (expanded(category.id))
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
    return CustomScrollView(
      slivers: [
        for (final category in categories)
          if (byCategory[category.id] case final items?) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(name: category.name, items: items),
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

/// カテゴリの見出し（カテゴリ名・件数。開閉できる場合は ▼ と、閉じたときの要約も出す）
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.name,
    required this.items,
    this.expanded = true,
    this.onTap,
  });

  final String name;
  final List<Item> items;

  /// 中身を表示しているか
  final bool expanded;

  /// 押したときの処理（null なら開閉できない）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = countByStatus(items);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              if (onTap != null)
                AnimatedRotation(
                  turns: expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: colors.primary,
                  ),
                ),
              const SizedBox(width: 2),
              // Flexible にすると区切り線と幅を分け合って線が途中で切れるので、最大幅で抑える
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 閉じているときは、買う必要のあるものの件数だけ出す
              if (!expanded)
                for (final status in [StockStatus.empty, StockStatus.low])
                  if ((counts[status] ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Icon(status.icon, size: 14, color: status.color),
                    const SizedBox(width: 2),
                    Text(
                      '${counts[status]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: status.onLightColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
              const SizedBox(width: 8),
              Expanded(child: Divider(color: colors.outlineVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
