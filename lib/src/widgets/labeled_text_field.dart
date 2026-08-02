import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.helper,
    required this.controller,
    this.placeholder,
    this.minLines = 2,
    this.maxLines = 4,
    this.onChanged,
  });

  final String label;
  final String helper;
  final String? placeholder;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: colors.textPrimary,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
          ),
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
