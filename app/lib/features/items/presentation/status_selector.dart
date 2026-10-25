import 'package:flutter/material.dart';

import '../domain/stock_status.dart';
import 'status_colors.dart';

/// 「十分 / 残りわずか / 切れてる」を切り替えるボタン
class StatusSelector extends StatelessWidget {
  const StatusSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final StockStatus selected;
  final ValueChanged<StockStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StockStatus>(
        segments: [
          for (final status in StockStatus.values)
            ButtonSegment(value: status, label: Text(status.label)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          // 選ばれているのは常に selected なので、その色で塗る
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? selected.color.withValues(alpha: 0.25)
                : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? selected.onLightColor
                : null,
          ),
        ),
      ),
    );
  }
}
