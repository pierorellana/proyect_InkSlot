import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';

class AdminRequestsPlaceholder extends StatelessWidget {
  const AdminRequestsPlaceholder({
    super.key,
    this.title = 'Solicitudes',
    this.description =
        'La bandeja de solicitudes se conectará aquí en el siguiente slice.',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const InkSlotMonoLabel('Espacio de trabajo'),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 36),
          Container(
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: InkSlotColors.surface,
              borderRadius: BorderRadius.circular(InkSlotRadii.card),
              border: Border.all(color: InkSlotColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: InkSlotColors.tobacco,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inbox_outlined,
                    color: InkSlotColors.copperLight,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Módulo en preparación',
                  style: TextStyle(
                    color: InkSlotColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'No hay datos simulados. Esta vista quedará conectada a la API en el siguiente paso.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
