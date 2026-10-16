import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';
import 'booking_requests_controller.dart';
import 'widgets/contact_channel_field.dart';
import 'widgets/request_form_sections.dart';

class NewBookingRequestPage extends StatefulWidget {
  const NewBookingRequestPage({required this.controller, super.key});

  final BookingRequestsController controller;

  @override
  State<NewBookingRequestPage> createState() => _NewBookingRequestPageState();
}

class _NewBookingRequestPageState extends State<NewBookingRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _referenceController = TextEditingController();

  ContactChannel _channel = ContactChannel.whatsapp;
  bool _depositVerified = false;
  bool _hasRestrictions = false;
  String? _depositError;
  int _durationMinutes = 180;
  int _ttlHours = 48;
  DateTime? _preferredDate;
  Set<int> _preferredDays = <int>{2, 3, 4, 5, 6};
  String? _preferredTimeRange;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!_depositVerified) {
      setState(() => _depositError = 'Confirma el anticipo para continuar.');
    } else {
      setState(() => _depositError = null);
    }
    if (!valid || !_depositVerified) return;

    widget.controller.clearError();
    final input = CreateBookingRequestInput(
      clientName: _nameController.text.trim(),
      contactChannel: _channel,
      contactValue: _contactController.text.trim(),
      paymentReference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      depositVerified: true,
      durationMinutes: _durationMinutes,
      preferredDate: _hasRestrictions ? _preferredDate : null,
      preferredTimeRange: _hasRestrictions ? _preferredTimeRange : null,
      preferredDays: _hasRestrictions
          ? _preferredDays.map(_dayLabel).toList(growable: false)
          : const <String>[],
      tokenTtlHours: _ttlHours,
    );

    final link = await widget.controller.create(input);
    if (!mounted || link == null) return;
    context.go('/admin/requests/link', extra: link);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _preferredDate ?? now,
      helpText: 'Selecciona una fecha preferida',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (date != null && mounted) setState(() => _preferredDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PageHeader(
                  eyebrow: 'Solicitudes · nueva',
                  title: 'Crea un espacio\npara reservar.',
                  onBack: () => context.go('/admin/requests'),
                ),
                const SizedBox(height: 28),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _clientSection()),
                      const SizedBox(width: 16),
                      Expanded(child: _depositSection()),
                    ],
                  )
                else ...[
                  _clientSection(),
                  const SizedBox(height: 16),
                  _depositSection(),
                ],
                const SizedBox(height: 16),
                RequestSection(
                  label: '02 · Sesión',
                  title: 'Define el tiempo del tatuaje.',
                  child: RequestDurationField(
                    value: _durationMinutes,
                    onChanged: (value) =>
                        setState(() => _durationMinutes = value),
                  ),
                ),
                const SizedBox(height: 16),
                _restrictionsSection(),
                const SizedBox(height: 16),
                RequestSection(
                  label: '04 · Enlace privado',
                  title: 'Dale un margen para decidir.',
                  child: RequestTtlField(
                    value: _ttlHours,
                    onChanged: (value) => setState(() => _ttlHours = value),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, child) {
                    final submitting =
                        widget.controller.mutationStatus ==
                        BookingRequestMutationStatus.submitting;
                    final error = widget.controller.mutationError;
                    final duration = MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : InkSlotMotion.micro;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: duration,
                          child: error == null
                              ? const SizedBox.shrink(key: ValueKey('no-error'))
                              : Padding(
                                  key: const ValueKey('request-error'),
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error,
                                      style: const TextStyle(
                                        color: InkSlotColors.errorText,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        InkSlotPrimaryButton(
                          label: submitting
                              ? 'Creando enlace…'
                              : 'Crear solicitud',
                          onPressed: submitting ? null : _submit,
                          trailing: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: InkSlotColors.ink,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward, size: 20),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: submitting
                              ? null
                              : () => context.go('/admin/requests'),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientSection() => RequestSection(
    label: '01 · Cliente',
    title: '¿Para quién es este espacio?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if ((value?.trim().length ?? 0) < 2) {
              return 'Ingresa el nombre del cliente.';
            }
            return null;
          },
          decoration: _fieldDecoration(
            'Nombre del cliente',
            hintText: 'Nombre y apellido',
          ),
        ),
        const SizedBox(height: 16),
        ContactChannelField(
          channel: _channel,
          controller: _contactController,
          onChannelChanged: (channel) => setState(() => _channel = channel),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _referenceController,
          textInputAction: TextInputAction.next,
          maxLength: 160,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length > 160) return 'Usa máximo 160 caracteres.';
            return null;
          },
          decoration: _fieldDecoration(
            'Referencia del anticipo · opcional',
            hintText: 'Ej. Transferencia 0045',
            counterText: '',
          ),
        ),
      ],
    ),
  );

  Widget _depositSection() => RequestSection(
    label: '01 · Anticipo',
    title: 'Confirma el punto de partida.',
    child: DepositConfirmationField(
      value: _depositVerified,
      error: _depositError,
      onChanged: (value) => setState(() {
        _depositVerified = value;
        if (value) _depositError = null;
      }),
    ),
  );

  Widget _restrictionsSection() => RequestSection(
    label: '03 · Restricciones',
    title: 'Comparte cuándo le viene bien.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Añadir preferencias de agenda',
          toggled: _hasRestrictions,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Switch.adaptive(
                value: _hasRestrictions,
                onChanged: (value) => setState(() => _hasRestrictions = value),
                activeThumbColor: InkSlotColors.copper,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Añadir preferencias de agenda',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Son una guía; el cliente elegirá entre los espacios disponibles.',
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
        if (_hasRestrictions) ...[
          const SizedBox(height: 12),
          const Text(
            'Días preferidos',
            style: TextStyle(
              color: InkSlotColors.cream,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          RequestDaysField(
            values: _preferredDays,
            onChanged: (values) => setState(() => _preferredDays = values),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: _fieldDecoration(
                'Fecha preferida · opcional',
                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
              ),
              child: Text(
                _preferredDate == null
                    ? 'Elegir una fecha'
                    : _formatDate(_preferredDate!),
                style: TextStyle(
                  color: _preferredDate == null
                      ? InkSlotColors.tertiary
                      : InkSlotColors.cream,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _preferredTimeRange,
            decoration: _fieldDecoration(
              'Franja horaria · opcional',
              prefixIcon: const Icon(Icons.schedule_outlined, size: 20),
            ),
            hint: const Text('Cualquier horario'),
            items: const [
              DropdownMenuItem(
                value: '09:00–12:00',
                child: Text('Mañana · 09:00–12:00'),
              ),
              DropdownMenuItem(
                value: '12:00–16:00',
                child: Text('Mediodía · 12:00–16:00'),
              ),
              DropdownMenuItem(
                value: '16:00–20:00',
                child: Text('Tarde · 16:00–20:00'),
              ),
            ],
            onChanged: (value) => setState(() => _preferredTimeRange = value),
          ),
        ],
      ],
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.onBack,
  });

  final String eyebrow;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Volver a solicitudes',
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          InkSlotMonoLabel(eyebrow, color: InkSlotColors.copperLight),
        ],
      ),
      const SizedBox(height: 18),
      Text(title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 12),
      Text(
        'Prepara una solicitud clara y entrega un enlace privado listo para compartir.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

InputDecoration _fieldDecoration(
  String label, {
  String? hintText,
  Widget? prefixIcon,
  String? counterText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  prefixIcon: prefixIcon,
  counterText: counterText,
  filled: true,
  fillColor: InkSlotColors.field,
  labelStyle: const TextStyle(color: InkSlotColors.secondary),
  hintStyle: const TextStyle(color: InkSlotColors.tertiary),
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.copper, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: InkSlotColors.error, width: 1.5),
  ),
);

String _dayLabel(int value) => switch (value) {
  1 => 'lunes',
  2 => 'martes',
  3 => 'miércoles',
  4 => 'jueves',
  5 => 'viernes',
  6 => 'sábado',
  7 => 'domingo',
  _ => 'lunes',
};

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';
