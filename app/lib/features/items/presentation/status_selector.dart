import 'package:flutter/material.dart';

import '../domain/stock_status.dart';
import 'status_colors.dart';

/// 「十分 / 残りわずか / 切れてる」を切り替えるボタン（アイコン＋名前）
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
            ButtonSegment(
              value: status,
              icon: Icon(status.icon),
              label: Text(status.label),
            ),
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

/// 一覧用の小さな切り替えボタン（アイコンだけ。名前は凡例で示す）
class StatusIconSelector extends StatelessWidget {
  const StatusIconSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final StockStatus selected;
  final ValueChanged<StockStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in StockStatus.values)
          Tooltip(
            message: status.label,
            child: Semantics(
              button: true,
              selected: status == selected,
              label: status.label,
              child: InkResponse(
                radius: 20,
                onTap: status == selected ? null : () => onChanged(status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == selected
                        ? status.color.withValues(alpha: 0.18)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    status.icon,
                    size: 24,
                    color: status == selected ? status.color : muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ステータスの凡例（アイコンと名前。件数を渡すと横に出す）
class StatusLegend extends StatelessWidget {
  const StatusLegend({super.key, this.counts});

  final Map<StockStatus, int>? counts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final status in StockStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 16, color: status.color),
              const SizedBox(width: 4),
              Text(status.label, style: textTheme.labelMedium),
              if (counts case final counts?) ...[
                const SizedBox(width: 4),
                Text(
                  '${counts[status] ?? 0}',
                  style: textTheme.labelMedium?.copyWith(
                    color: status.onLightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
