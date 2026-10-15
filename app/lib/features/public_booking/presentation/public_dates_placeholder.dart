import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_page.dart';

class PublicDatesPlaceholder extends StatelessWidget {
  const PublicDatesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => InkSlotPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
        ),
        const SizedBox(height: 42),
        const InkSlotMonoLabel('Próximo paso'),
        const SizedBox(height: 18),
        const Text(
          'Fechas de reserva',
          style: TextStyle(
            color: InkSlotColors.cream,
            fontFamily: 'Instrument Serif',
            fontSize: 44,
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'La disponibilidad se conectará en el siguiente slice. Esta pantalla confirma la navegación del enlace privado.',
          style: TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
