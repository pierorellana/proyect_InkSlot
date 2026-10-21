import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../admin/presentation/admin_layout.dart';
import '../../admin/presentation/admin_motion.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';
import 'booking_requests_controller.dart';
import 'link_ready_page.dart';
import 'widgets/contact_channel_field.dart';
import 'widgets/request_form_sections.dart';

class NewBookingRequestPage extends StatefulWidget {
  const NewBookingRequestPage({required this.controller, super.key});

  final BookingRequestsController controller;

  @override
  State<NewBookingRequestPage> createState() => _NewBookingRequestPageState();
}

class _NewBookingRequestPageState extends State<NewBookingRequestPage> {
  static const _timeRanges = <(String, String?)>[
    ('Mañana', '09:00–12:00'),
    ('Mediodía', '12:00–16:00'),
    ('Tarde', '16:00–20:00'),
    ('Todo el día', null),
  ];

  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _referenceController = TextEditingController();

  ContactChannel _channel = ContactChannel.whatsapp;
  bool _depositVerified = false;
  bool _hasRestrictions = false;
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

  List<String> get _missing => [
    if (_nameController.text.trim().length < 2) 'nombre del cliente',
    if (ContactChannelField.validate(_channel, _contactController.text) != null)
      'dato de contacto',
    if (_referenceController.text.trim().length > 160)
      'referencia de máximo 160 caracteres',
    if (!_depositVerified) 'confirmar anticipo',
  ];

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_missing.isNotEmpty) return;

    widget.controller.clearError();
    final reference = _referenceController.text.trim();
    final input = CreateBookingRequestInput(
      clientName: _nameController.text.trim(),
      contactChannel: _channel,
      contactValue: _contactController.text.trim(),
      paymentReference: reference.isEmpty ? null : reference,
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
    context.go(
      '/admin/requests/link',
      extra: LinkReadyArgs(
        link: link,
        clientName: input.clientName,
        durationMinutes: input.durationMinutes,
      ),
    );
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
    final topInset = adminPageTopInset(context);
    return AdminScaleIn(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, topInset, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ANTICIPO',
                            style: inkSlotMono(color: InkSlotColors.tertiary),
                          ),
                          const SizedBox(width: 6),
                          const InkSlotIcon(
                            InkSlotIcons.flechaDerecha,
                            size: 12,
                            color: InkSlotColors.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ENLACE',
                            style: inkSlotMono(color: InkSlotColors.tertiary),
                          ),
                        ],
                      ),
                      InkSlotIconButton(
                        icon: InkSlotIcons.cerrar,
                        semanticLabel: 'Cerrar',
                        onPressed: () => context.go('/admin/requests'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Nueva solicitud', style: inkSlotSerif(42)),
                  _clientSection(),
                  _depositSection(),
                  RequestSection(
                    label: '03 · Duración',
                    child: RequestDurationField(
                      value: _durationMinutes,
                      onChanged: (value) =>
                          setState(() => _durationMinutes = value),
                    ),
                  ),
                  _restrictionsSection(),
                  RequestSection(
                    label: '05 · Vigencia del enlace',
                    child: RequestTtlField(
                      value: _ttlHours,
                      onChanged: (value) => setState(() => _ttlHours = value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomBar(
            controller: widget.controller,
            missing: _missing,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Widget _clientSection() {
    final contactText = _contactController.text;
    return RequestSection(
      label: '01 · Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkSlotField(
            label: 'Nombre',
            controller: _nameController,
            hint: 'Ej. Valentina Rosero',
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          ContactChannelField(
            channel: _channel,
            controller: _contactController,
            onChannelChanged: (channel) {
              if (channel == _channel) return;
              _contactController.clear();
              setState(() => _channel = channel);
            },
            onChanged: (_) => setState(() {}),
            errorText: contactText.trim().isEmpty
                ? null
                : ContactChannelField.validate(_channel, contactText),
          ),
        ],
      ),
    );
  }

  Widget _depositSection() => RequestSection(
    label: '02 · Anticipo',
    child: InkSlotCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DepositConfirmationField(
            value: _depositVerified,
            onChanged: (value) => setState(() => _depositVerified = value),
          ),
          const SizedBox(height: 14),
          InkSlotField(
            label: 'Referencia (opcional)',
            controller: _referenceController,
            hint: 'Ej. Transf. 0045',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
  );

  Widget _restrictionsSection() => RequestSection(
    label: '04 · Restricciones (opcional)',
    child: InkSlotCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Limitar fechas u horas',
                      style: TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Solo reduce tu jornada; nunca la amplía.',
                      style: TextStyle(color: Color(0xFF9B968E), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkSlotSwitch(
                value: _hasRestrictions,
                semanticLabel: 'Limitar fechas u horas',
                onChanged: (value) => setState(() => _hasRestrictions = value),
              ),
            ],
          ),
          if (_hasRestrictions)
            AdminScaleRise(
              duration: const Duration(milliseconds: 650),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SubLabel('Días permitidos'),
                    const SizedBox(height: 14),
                    RequestDaysField(
                      values: _preferredDays,
                      onChanged: (values) =>
                          setState(() => _preferredDays = values),
                    ),
                    const SizedBox(height: 14),
                    const _SubLabel('Fecha preferida'),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkSlotChip(
                        label: _preferredDate == null
                            ? 'Elegir una fecha'
                            : _formatDate(_preferredDate!),
                        icon: InkSlotIcons.calendario,
                        selected: _preferredDate != null,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SubLabel('Franja'),
                    const SizedBox(height: 14),
                    InkSlotSegmented(
                      labels: [for (final (label, _) in _timeRanges) label],
                      selected: _timeRanges
                          .indexWhere((item) => item.$2 == _preferredTimeRange)
                          .clamp(0, _timeRanges.length - 1),
                      onChanged: (index) => setState(
                        () => _preferredTimeRange = _timeRanges[index].$2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: InkSlotColors.secondary, fontSize: 13),
  );
}

/// Barra inferior fija: "Falta: …" y botón de crear, con blur de 16.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.missing,
    required this.onSubmit,
  });

  final BookingRequestsController controller;
  final List<String> missing;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.paddingOf(context).bottom + 6 < 30
              ? 30
              : MediaQuery.paddingOf(context).bottom + 6,
        ),
        decoration: const BoxDecoration(
          color: Color(0xEB0A0A0B),
          border: Border(top: BorderSide(color: Color(0x0FEEE9E0))),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final submitting =
                controller.mutationStatus ==
                BookingRequestMutationStatus.submitting;
            final error = controller.mutationError;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: InkSlotColors.errorText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else if (missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Falta: ${missing.join(' · ')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9B968E),
                        fontSize: 12,
                      ),
                    ),
                  ),
                InkSlotPrimaryButton(
                  label: submitting ? 'Creando…' : 'Crear y generar enlace',
                  loading: submitting,
                  onPressed: missing.isEmpty ? onSubmit : null,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

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
