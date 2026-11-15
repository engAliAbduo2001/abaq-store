import 'package:flutter/material.dart';

import '../theme/abaq_theme.dart';

class PromoCodeBox extends StatelessWidget {
  const PromoCodeBox({
    required this.controller,
    required this.isApplying,
    required this.error,
    required this.appliedCode,
    required this.discount,
    required this.onChanged,
    required this.onApply,
    required this.onRemove,
    super.key,
  });

  final TextEditingController controller;
  final bool isApplying;
  final String? error;
  final String? appliedCode;
  final double discount;
  final ValueChanged<String> onChanged;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROMO CODE',
            style: TextStyle(fontSize: 10, letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('promo-code-input'),
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    hintText: 'Enter code',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('apply-promo-code'),
                onPressed: isApplying ? null : onApply,
                child: isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('APPLY'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: palette.danger, fontSize: 12),
            ),
          ],
          if (appliedCode != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: palette.accent, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$appliedCode applied · You save \$${discount.toStringAsFixed(2)}',
                    style: TextStyle(color: palette.accent, fontSize: 12),
                  ),
                ),
                TextButton(
                  key: const ValueKey('remove-promo-code'),
                  onPressed: onRemove,
                  child: const Text('REMOVE'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
