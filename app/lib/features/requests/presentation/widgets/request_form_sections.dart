import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_icon.dart';
import '../../../../core/widgets/inkslot_kit.dart';
import '../../../../core/widgets/inkslot_motion.dart';
import '../../../admin/presentation/admin_date_format.dart';
import '../../../admin/presentation/admin_motion.dart';

/// Bloque numerado del formulario: etiqueta mono (`01 · Cliente`) y contenido.
class RequestSection extends StatelessWidget {
  const RequestSection({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(
          label.toUpperCase(),
          style: inkSlotMono(color: InkSlotColors.tertiary),
        ),
      ),
      child,
    ],
  );
}

/// Duración con pasos de 30 min y atajos (`1 h … 6 h`).
class RequestDurationField extends StatelessWidget {
  const RequestDurationField({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const secondary = TextStyle(color: InkSlotColors.secondary, fontSize: 15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSlotCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: InkSlotIcons.menos,
                label: 'Restar 30 minutos',
                enabled: enabled && value > 30,
                onPressed: () => onChanged((value - 30).clamp(30, 600)),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AdminTok(
                    token: value,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${value ~/ 60}',
                            style: inkSlotSerif(44),
                          ),
                          const TextSpan(text: ' h ', style: secondary),
                          TextSpan(
                            text: (value % 60).toString().padLeft(2, '0'),
                            style: inkSlotSerif(44),
                          ),
                          const TextSpan(text: ' min', style: secondary),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: InkSlotIcons.mas,
                label: 'Sumar 30 minutos',
                enabled: enabled && value < 600,
                onPressed: () => onChanged((value + 30).clamp(30, 600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final minutes in const [60, 120, 180, 240, 360]) ...[
                InkSlotChip(
                  label: durationLabel(minutes),
                  selected: value == minutes,
                  onTap: enabled ? () => onChanged(minutes) : null,
                ),
                if (minutes != 360) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Interruptor "Anticipo verificado" con su descripción.
class DepositConfirmationField extends StatelessWidget {
  const DepositConfirmationField({
    required this.value,
    required this.onChanged,
    super.key,
    this.error,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anticipo verificado',
                  style: TextStyle(
                    color: InkSlotColors.bone,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Confirmo que el pago ya llegó por un canal externo.',
                  style: TextStyle(
                    color: Color(0xFF9B968E),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          InkSlotSwitch(
            value: value,
            semanticLabel: 'Anticipo verificado',
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(
          error!,
          style: const TextStyle(color: InkSlotColors.errorText, fontSize: 13),
        ),
      ],
    ],
  );
}

/// Vigencia del enlace (`24 h · 48 h · 72 h`).
class RequestTtlField extends StatelessWidget {
  const RequestTtlField({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  static const options = [24, 48, 72];

  @override
  Widget build(BuildContext context) => InkSlotSegmented(
    labels: [for (final hours in options) '$hours h'],
    selected: options.indexOf(value).clamp(0, options.length - 1),
    onChanged: (index) {
      if (enabled) onChanged(options[index]);
    },
  );
}

/// Días permitidos: siete chips (`L M X J V S D`).
class RequestDaysField extends StatelessWidget {
  const RequestDaysField({
    required this.values,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final Set<int> values;
  final ValueChanged<Set<int>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: _DayChip(
              label: days[index],
              selected: values.contains(index + 1),
              onTap: enabled
                  ? () {
                      final next = {...values};
                      if (!next.add(index + 1)) next.remove(index + 1);
                      onChanged(next);
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: InkSlotPress(
      onTap: onTap,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? InkSlotColors.bone : Colors.transparent,
            borderRadius: BorderRadius.circular(InkSlotRadii.chip),
            border: Border.all(
              color: selected ? InkSlotColors.bone : const Color(0x24EEE9E0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: selected ? InkSlotColors.ink : InkSlotColors.bone,
            ),
          ),
        ),
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final InkSlotIcons icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .3,
    child: InkSlotPress(
      semanticLabel: label,
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x0FEEE9E0),
          border: Border.all(color: InkSlotColors.line),
        ),
        alignment: Alignment.center,
        child: InkSlotIcon(icon, size: 18, color: InkSlotColors.bone),
      ),
    ),
  );
}
