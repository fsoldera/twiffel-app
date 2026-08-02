import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Large selectable routing card with radio affordance.
class OptionSelectCard extends StatelessWidget {
  const OptionSelectCard({
    super.key,
    required this.title,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? colors.selectedFill : colors.softFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? TwiffelTokens.primary400
                  : colors.borderDefault,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.isDark
                    ? const Color(0x33000000)
                    : const Color(0x08000000),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RadioDot(selected: selected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                helper,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
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
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: TwiffelTokens.primaryDefault,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
