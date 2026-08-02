import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Single-select radio list with an optional "Other" free-text field.
class RadioOptionList extends StatelessWidget {
  const RadioOptionList({
    super.key,
    required this.label,
    required this.helper,
    required this.options,
    required this.otherLabel,
    required this.selectedIndex,
    required this.otherController,
    required this.onSelected,
    this.onOtherChanged,
  });

  final String label;
  final String helper;
  final List<String> options;
  final String otherLabel;

  /// Index into [options], or [options.length] when Other is selected.
  final int? selectedIndex;
  final TextEditingController otherController;
  final ValueChanged<int> onSelected;
  final ValueChanged<String>? onOtherChanged;

  int get _otherIndex => options.length;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final otherSelected = selectedIndex == _otherIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RadioRow(
            label: options[i],
            selected: selectedIndex == i,
            onTap: () => onSelected(i),
          ),
        ],
        const SizedBox(height: 12),
        _RadioRow(
          label: otherLabel,
          selected: otherSelected,
          onTap: () => onSelected(_otherIndex),
        ),
        if (otherSelected) ...[
          const SizedBox(height: 10),
          TextField(
            controller: otherController,
            onChanged: onOtherChanged,
            decoration: const InputDecoration(
              hintText: 'Tell us more...',
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

class _RadioRow extends StatelessWidget {
  const _RadioRow({
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? TwiffelTokens.primaryDefault
                      : colors.borderStrong,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: TwiffelTokens.primaryDefault,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
