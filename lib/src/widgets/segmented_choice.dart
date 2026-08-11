import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-width equal-height timing options (stacked), with optional date range.
class SegmentedChoice extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.label,
    required this.helper,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.dateRangeOptionIndex,
    this.dateRangeSummary,
    this.pickDatesLabel = 'Pick date range',
    this.onPickDates,
  });

  final String label;
  final String helper;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  /// When set, selecting this index shows the date-range summary row.
  final int? dateRangeOptionIndex;
  final String? dateRangeSummary;
  final String pickDatesLabel;
  final VoidCallback? onPickDates;

  static const double _rowMinHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final showDateRow = dateRangeOptionIndex != null &&
        selectedIndex == dateRangeOptionIndex &&
        onPickDates != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TimingRow(
            label: options[i],
            selected: selectedIndex == i,
            minHeight: _rowMinHeight,
            onTap: () => onSelected(i),
          ),
        ],
        if (showDateRow) ...[
          const SizedBox(height: 12),
          _TimingRow(
            label: dateRangeSummary?.isNotEmpty == true
                ? dateRangeSummary!
                : pickDatesLabel,
            selected: dateRangeSummary?.isNotEmpty == true,
            minHeight: _rowMinHeight,
            onTap: onPickDates!,
            trailing: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          helper,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.label,
    required this.selected,
    required this.minHeight,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final double minHeight;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Material(
      color: selected ? colors.selectedFill : colors.softFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? TwiffelTokens.primaryDefault
                    : colors.borderDefault,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? (colors.isDark
                              ? TwiffelTokens.primary300
                              : TwiffelTokens.primaryDefault)
                          : colors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
