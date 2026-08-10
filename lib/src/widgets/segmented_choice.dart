import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Three equal timing chips (Figma segmented-chips style).
class SegmentedChoice extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.label,
    required this.helper,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final String helper;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

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
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Chip(
                  label: options[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
            ],
          ],
        ),
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Material(
      color: selected ? colors.selectedFill : colors.softFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? TwiffelTokens.primaryDefault
                  : colors.borderDefault,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? (colors.isDark
                      ? TwiffelTokens.primary300
                      : TwiffelTokens.primaryDefault)
                  : colors.textSecondary,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
