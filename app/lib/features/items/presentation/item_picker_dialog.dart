import 'package:flutter/material.dart';

import '../../../core/utils/text_normalizer.dart';
import '../domain/item.dart';

/// アイテムを 1 つ選ぶダイアログ（名前で絞り込める）。選ばれたアイテムを返す
Future<Item?> showItemPickerDialog(
  BuildContext context, {
  required String title,
  required List<Item> items,
}) {
  return showDialog<Item>(
    context: context,
    builder: (context) => _ItemPickerDialog(title: title, items: items),
  );
}

class _ItemPickerDialog extends StatefulWidget {
  const _ItemPickerDialog({required this.title, required this.items});

  final String title;
  final List<Item> items;

  @override
  State<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<_ItemPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = normalizeForCompare(_query);
    final shown =
        widget.items
            .where(
              (item) =>
                  query.isEmpty ||
                  normalizeForCompare(item.name).contains(query),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'アイテム名で検索',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('該当するアイテムがありません'))
                  : ListView(
                      children: [
                        for (final item in shown)
                          ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: item.memo.isEmpty
                                ? null
                                : Text(
                                    item.memo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.pop(context, item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
