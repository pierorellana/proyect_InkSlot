import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_mono_label.dart';

class RequestSection extends StatelessWidget {
  const RequestSection({
    required this.label,
    required this.title,
    required this.child,
    super.key,
  });

  final String label;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSlotMonoLabel(label, color: InkSlotColors.copperLight),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            label: 'Reducir duración',
            enabled: enabled && value > 30,
            onPressed: () => onChanged((value - 30).clamp(30, 600)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _durationLabel(value),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: InkSlotColors.cream,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'duración de la sesión',
                  style: TextStyle(
                    color: InkSlotColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            label: 'Aumentar duración',
            enabled: enabled && value < 600,
            onPressed: () => onChanged((value + 30).clamp(30, 600)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [60, 120, 180, 240, 360]
            .map(
              (minutes) => _ChoiceChip(
                label: _durationLabel(minutes),
                selected: value == minutes,
                enabled: enabled,
                onPressed: () => onChanged(minutes),
              ),
            )
            .toList(growable: false),
      ),
    ],
  );
}

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
      Semantics(
        container: true,
        label: 'Confirmación de anticipo',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? (next) => onChanged(next ?? false) : null,
              activeColor: InkSlotColors.copper,
              checkColor: InkSlotColors.ink,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anticipo recibido y verificado',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'El enlace solo se podrá usar cuando el anticipo esté confirmado.',
                      style: TextStyle(
                        color: InkSlotColors.secondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(
          error!,
          style: const TextStyle(color: InkSlotColors.errorText, fontSize: 12),
        ),
      ],
    ],
  );
}

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

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Vigencia del enlace',
        style: TextStyle(
          color: InkSlotColors.cream,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Después de este tiempo, el cliente ya no podrá reservar.',
        style: TextStyle(color: InkSlotColors.secondary, fontSize: 13),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [24, 48, 72]
            .map(
              (hours) => _ChoiceChip(
                label: '$hours h',
                selected: value == hours,
                enabled: enabled,
                onPressed: () => onChanged(hours),
              ),
            )
            .toList(growable: false),
      ),
    ],
  );
}

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(days.length, (index) {
        final selected = values.contains(index + 1);
        return _ChoiceChip(
          label: days[index],
          selected: selected,
          enabled: enabled,
          onPressed: () {
            final next = {...values};
            if (selected) {
              next.remove(index + 1);
            } else {
              next.add(index + 1);
            }
            onChanged(next);
          },
        );
      }),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      tooltip: label,
      style: IconButton.styleFrom(
        foregroundColor: InkSlotColors.copperLight,
        backgroundColor: InkSlotColors.tobacco,
        minimumSize: const Size(44, 44),
      ),
    ),
  );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onPressed() : null,
      showCheckmark: false,
      side: const BorderSide(color: InkSlotColors.lineStrong),
      selectedColor: InkSlotColors.tobacco,
      backgroundColor: InkSlotColors.field,
      labelStyle: TextStyle(
        color: selected ? InkSlotColors.copperLight : InkSlotColors.secondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}
