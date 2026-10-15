import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import 'widgets/flash_mosaic.dart';

class PublicWelcomePage extends StatelessWidget {
  const PublicWelcomePage({
    required this.token,
    required this.onChooseDate,
    super.key,
  });

  final String token;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 34),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 720 ? 560 : 560,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FlashMosaic(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _WelcomeContent(onChooseDate: onChooseDate),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onChooseDate});

  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: InkSlotColors.copper,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const InkSlotMonoLabel(
            'Reserva abierta · vence en 47 h',
            color: InkSlotColors.copperLight,
          ),
        ],
      ),
      const SizedBox(height: 26),
      const Text.rich(
        TextSpan(
          text: 'Valentina,\n',
          children: [
            TextSpan(
              text: 'tu espacio te espera.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        style: TextStyle(
          color: InkSlotColors.cream,
          fontFamily: 'Instrument Serif',
          fontSize: 44,
          height: 0.98,
        ),
      ),
      const SizedBox(height: 28),
      const _SummaryCard(),
      const SizedBox(height: 24),
      const _ArtistRow(),
      const SizedBox(height: 28),
      InkSlotPrimaryButton(
        label: 'Elegir fecha y hora',
        onPressed: onChooseDate,
        trailing: const Icon(Icons.arrow_forward, size: 22),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () {},
        child: const Text('¿Dudas? Escríbele al estudio'),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: const IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(label: 'Sesión', value: '3 horas'),
          ),
          VerticalDivider(width: 1, color: InkSlotColors.line),
          Expanded(
            child: _SummaryItem(
              label: 'Anticipo',
              value: 'Validado ✓',
              valueColor: InkSlotColors.successText,
            ),
          ),
          VerticalDivider(width: 1, color: InkSlotColors.line),
          Expanded(
            child: _SummaryItem(label: 'Días', value: 'Mar – Sáb'),
          ),
        ],
      ),
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkSlotMonoLabel(label),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? InkSlotColors.cream,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: InkSlotColors.tobacco,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          'D',
          style: TextStyle(
            color: InkSlotColors.bone,
            fontFamily: 'Instrument Serif',
            fontSize: 32,
          ),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gio · Dodogio Studio',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: InkSlotColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Hasta el 30 nov · hora de Ecuador',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: InkSlotColors.secondary, fontSize: 14),
            ),
          ],
        ),
      ),
    ],
  );
}
