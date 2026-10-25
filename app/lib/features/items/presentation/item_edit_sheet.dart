import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/relative_time.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../shared/widgets/snack_bars.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/items_repository.dart';
import '../domain/category.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';
import 'items_providers.dart';
import 'status_selector.dart';

/// アイテム追加・編集のシートを開く（[item] を渡すと編集）
Future<void> showItemEditSheet(
  BuildContext context, {
  Item? item,
  String? initialCategoryId,
  StockStatus initialStatus = StockStatus.sufficient,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ItemEditSheet(
      item: item,
      initialCategoryId: initialCategoryId,
      initialStatus: initialStatus,
    ),
  );
}

/// アイテム追加・編集のシート
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({
    super.key,
    this.item,
    this.initialCategoryId,
    this.initialStatus = StockStatus.sufficient,
  });

  final Item? item;
  final String? initialCategoryId;
  final StockStatus initialStatus;

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
  static const _maxNameLength = 50;
  static const _maxMemoLength = 200;
  static const _maxCategoryNameLength = 20;

  /// カテゴリの選択肢の末尾に置く「＋ カテゴリ追加」の値
  static const _addCategoryValue = '__add_category__';

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.item?.name ?? '',
  );
  late final _memoController = TextEditingController(
    text: widget.item?.memo ?? '',
  );
  late String _categoryId =
      widget.item?.categoryId ?? widget.initialCategoryId ?? Category.otherId;
  late StockStatus _status = widget.item?.status ?? widget.initialStatus;

  /// カテゴリの選択肢を作り直すための番号（追加をキャンセルしたとき元に戻す）
  int _categoryFieldVersion = 0;
  bool _saving = false;
  bool _closedByDeletion = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String? _validateName(
    String? value,
    List<Item> items,
    List<Category> categories,
  ) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'アイテム名を入力してください';
    if (name.length > _maxNameLength) return '$_maxNameLength文字以内で入力してください';

    final key = normalizeForCompare(name);
    final duplicate = items
        .where(
          (item) =>
              item.id != widget.item?.id &&
              normalizeForCompare(item.name) == key,
        )
        .firstOrNull;
    if (duplicate == null) return null;
    final categoryName =
        categories
            .where((c) => c.id == duplicate.categoryId)
            .firstOrNull
            ?.name ??
        'その他';
    return '同じ名前のアイテムがすでにあります（カテゴリ: $categoryName）';
  }

  Future<void> _addCategory(List<Category> categories) async {
    final name = await showTextInputDialog(
      context,
      title: 'カテゴリを追加',
      label: 'カテゴリ名',
      maxLength: _maxCategoryNameLength,
      validator: (value) {
        if (value.isEmpty) return 'カテゴリ名を入力してください';
        if (value.length > _maxCategoryNameLength) {
          return '$_maxCategoryNameLength文字以内で入力してください';
        }
        final key = normalizeForCompare(value);
        if (categories.any((c) => normalizeForCompare(c.name) == key)) {
          return '同じ名前のカテゴリがすでにあります';
        }
        return null;
      },
    );
    if (!mounted) return;
    if (name == null) {
      // キャンセルしたら、選択肢の表示を元のカテゴリに戻す
      setState(() => _categoryFieldVersion++);
      return;
    }
    final id = await runWithErrorMessage(
      context,
      () => ref.read(itemsRepositoryProvider).addCategory(name, categories),
    );
    if (!mounted) return;
    setState(() {
      if (id != null) _categoryId = id;
      _categoryFieldVersion++;
    });
  }

  Future<void> _save(List<Category> categories) async {
    if (!_formKey.currentState!.validate()) return;
    final actor = ref.read(actorProvider);
    if (actor == null) return;

    // 選んでいたカテゴリがほかの人に削除されていたら「その他」にする
    final categoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : Category.otherId;
    final name = _nameController.text.trim();
    final memo = _memoController.text.trim();
    final repository = ref.read(itemsRepositoryProvider);

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final result = await runWithErrorMessage(context, () async {
      if (_isEdit) {
        await repository.updateItem(
          widget.item!.id,
          name: name,
          categoryId: categoryId,
          status: _status,
          memo: memo,
          actor: actor,
        );
      } else {
        await repository.addItem(
          name: name,
          categoryId: categoryId,
          status: _status,
          memo: memo,
          actor: actor,
        );
      }
      return true;
    });
    if (!mounted) return;
    if (result == true) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  /// 編集中にほかの人がアイテムを削除したら、シートを閉じて知らせる
  void _closeIfDeleted(List<Item> items) {
    if (!_isEdit || _closedByDeletion) return;
    if (items.any((item) => item.id == widget.item!.id)) return;
    _closedByDeletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showMessage(messenger, 'このアイテムは削除されました');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    if (ref.watch(itemsProvider).hasValue) _closeIfDeleted(items);

    final selectedCategoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : (categories.any((c) => c.id == Category.otherId)
              ? Category.otherId
              : null);
    final current = widget.item == null
        ? null
        : items.where((item) => item.id == widget.item!.id).firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'アイテムを編集' : 'アイテムを追加',
                style: theme.textTheme.titleLarge,
              ),
              if (current != null) ...[
                const SizedBox(height: 4),
                Text(
                  '最終更新: ${current.updatedByName}・${formatRelativeTime(current.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEdit,
                maxLength: _maxNameLength,
                decoration: const InputDecoration(labelText: 'アイテム名'),
                validator: (value) => _validateName(value, items, categories),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('category-$_categoryFieldVersion'),
                initialValue: selectedCategoryId,
                decoration: const InputDecoration(labelText: 'カテゴリ'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  const DropdownMenuItem(
                    value: _addCategoryValue,
                    child: Text('＋ カテゴリ追加'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  if (value == _addCategoryValue) {
                    _addCategory(categories);
                  } else {
                    setState(() => _categoryId = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('ステータス', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              StatusSelector(
                selected: _status,
                onChanged: (status) => setState(() => _status = status),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _memoController,
                maxLength: _maxMemoLength,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  hintText: '例: 銘柄は〇〇、詰め替え用',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(categories),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
