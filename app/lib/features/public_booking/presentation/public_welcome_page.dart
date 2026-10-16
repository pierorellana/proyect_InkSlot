import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_appointment.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'public_studio_link.dart';
import 'widgets/flash_mosaic.dart';
import 'widgets/public_chrome.dart';
import 'widgets/public_format.dart';
import 'widgets/public_time_zone_formatter.dart';

class PublicWelcomePage extends StatefulWidget {
  const PublicWelcomePage({
    required this.token,
    required this.onChooseDate,
    required this.controller,
    super.key,
  });

  final String token;
  final VoidCallback onChooseDate;
  final PublicReservationController controller;

  @override
  State<PublicWelcomePage> createState() => _PublicWelcomePageState();
}

class _PublicWelcomePageState extends State<PublicWelcomePage> {
  bool _retrying = false;
  bool _appointmentRequested = false;

  @override
  void initState() {
    super.initState();
    _loadReservation();
  }

  @override
  void didUpdateWidget(covariant PublicWelcomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _appointmentRequested = false;
      _loadReservation();
    }
  }

  void _loadReservation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadReservation(widget.token);
    });
  }

  void _retry() {
    setState(() => _retrying = true);
    widget.controller.retryReservation();
  }

  void _loadBookedAppointment() {
    if (_appointmentRequested) return;
    _appointmentRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.appointment == null) {
        widget.controller.loadAppointment(widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PublicScreen(
    builder: (context, safe) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final status = controller.reservationStatus;
        if (status != PublicReservationStatus.loading) _retrying = false;
        final offline =
            status == PublicReservationStatus.error ||
            (status == PublicReservationStatus.loading && _retrying);
        if (status == PublicReservationStatus.booked) _loadBookedAppointment();
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!offline)
              const Positioned(top: 0, left: 0, right: 0, child: FlashMosaic()),
            Positioned(
              top: safe.top,
              left: 20,
              right: 20,
              child: const _WelcomeHeader(),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    safe.top + 60,
                    24,
                    40 + (safe.bottom - InkSlotSpacing.safeAreaBottomReference),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - safe.top - 60 - 40,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _WelcomeBody(
                        controller: controller,
                        offline: offline,
                        retrying: _retrying,
                        onRetry: _retry,
                        onChooseDate: widget.onChooseDate,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: InkSlotColors.bone,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const InkSlotLogo(
              size: 18,
              color: InkSlotColors.ink,
              semanticsLabel: 'Dodogio',
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'DODOGIO',
            style: inkSlotMono(
              size: 12,
              color: InkSlotColors.bone,
              spacing: .32,
            ),
          ),
        ],
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xB30A0A0B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FEEE9E0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const InkSlotIcon(
                  InkSlotIcons.candado,
                  size: 12,
                  color: Color(0xFFCFC9BF),
                ),
                const SizedBox(width: 6),
                Text(
                  'ENLACE PRIVADO',
                  style: inkSlotMono(size: 10, color: const Color(0xFFCFC9BF)),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody({
    required this.controller,
    required this.offline,
    required this.retrying,
    required this.onRetry,
    required this.onChooseDate,
  });

  final PublicReservationController controller;
  final bool offline;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) {
    final reservation = controller.reservation;
    final status = controller.reservationStatus;
    if (offline) return _OfflineBlock(retrying: retrying, onRetry: onRetry);
    if (status == PublicReservationStatus.idle ||
        status == PublicReservationStatus.loading ||
        (reservation == null && status == PublicReservationStatus.active)) {
      return const InkSlotRise(
        child: PublicTag(
          'Cargando tu reserva',
          color: InkSlotColors.copper,
          live: true,
        ),
      );
    }
    if (status != PublicReservationStatus.active) {
      final booked = controller.appointment;
      return PublicBlockedMessage(
        status: status,
        middle: status == PublicReservationStatus.booked && booked != null
            ? _BookedTicket(appointment: booked)
            : null,
      );
    }
    return _ActiveBlock(reservation: reservation!, onChooseDate: onChooseDate);
  }
}

class _ActiveBlock extends StatelessWidget {
  const _ActiveBlock({required this.reservation, required this.onChooseDate});

  final PublicReservation reservation;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) {
    final expiry = publicDateParts(reservation.expiresAt, reservation.timezone);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSlotRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PublicTag(
                'Reserva abierta · ${publicExpiryLabel(reservation.expiresAt)}',
                color: InkSlotColors.copper,
                live: true,
              ),
              const SizedBox(height: 12),
              Text(
                'Tu espacio te espera.',
                style: inkSlotSerif(
                  44,
                  italic: true,
                  color: const Color(0xFFCFC9BF),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        InkSlotRise.step(2, child: _SummaryCard(reservation: reservation)),
        const SizedBox(height: 22),
        InkSlotRise.step(
          3,
          child: _ArtistRow(
            name: reservation.artistDisplayName,
            subtitle:
                'Hasta el ${expiry.day} ${expiry.monthShort} · '
                '${publicZoneDescription(reservation.timezone).split(' (').first}',
          ),
        ),
        const SizedBox(height: 22),
        InkSlotRise.step(
          4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkSlotPrimaryButton(
                label: 'Elegir fecha y hora',
                onPressed: onChooseDate,
                trailing: const InkSlotIcon(
                  InkSlotIcons.flechaDerecha,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              PublicTextLink(
                '¿Dudas? Escríbele al estudio',
                onTap: () => contactPublicStudio(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.reservation});

  final PublicReservation reservation;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Sesión',
              value: Text(
                publicDurationLabel(reservation.durationMinutes),
                style: _valueStyle,
              ),
            ),
          ),
          const _SummaryDivider(),
          const Expanded(
            child: _SummaryItem(
              label: 'Anticipo',
              value: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text('Validado', style: _valueStyle),
                    SizedBox(width: 6),
                    InkSlotIcon(
                      InkSlotIcons.check,
                      size: 15,
                      color: InkSlotColors.success,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              label: 'Días',
              value: Text(
                _restrictionDays(reservation.restrictions.allowedWeekdays),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _valueStyle,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const _valueStyle = TextStyle(
  color: InkSlotColors.bone,
  fontSize: 17,
  fontWeight: FontWeight.w500,
);

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) =>
      const VerticalDivider(width: 1, thickness: 1, color: InkSlotColors.line);
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: inkSlotMono(size: 9, color: InkSlotColors.tertiary),
        ),
        const SizedBox(height: 6),
        value,
      ],
    ),
  );
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: InkSlotColors.tobacco,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const InkSlotLogo(
          size: 20,
          color: InkSlotColors.bone,
          semanticsLabel: 'Dodogio',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InkSlotColors.bone,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: InkSlotColors.ash, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OfflineBlock extends StatelessWidget {
  const _OfflineBlock({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkSlotRise(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: InkSlotColors.sheet,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1AEEE9E0)),
            ),
            alignment: Alignment.center,
            child: const InkSlotIcon(InkSlotIcons.sinConexion, size: 26),
          ),
        ),
      ),
      const SizedBox(height: 20),
      InkSlotRise.step(
        1,
        child: const PublicHeadline(
          title: 'Sin conexión.',
          body:
              'No pudimos cargar tu reserva. Tu solicitud y tu anticipo siguen guardados; vuelve a intentarlo cuando tengas señal.',
        ),
      ),
      const SizedBox(height: 20),
      InkSlotRise.step(
        2,
        child: Opacity(
          opacity: retrying ? .28 : 1,
          child: InkSlotPrimaryButton(
            label: retrying ? 'Conectando…' : 'Reintentar',
            loading: retrying,
            onPressed: retrying ? null : onRetry,
          ),
        ),
      ),
    ],
  );
}

class _BookedTicket extends StatelessWidget {
  const _BookedTicket({required this.appointment});

  final PublicAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final parts = publicDateParts(appointment.startAt, appointment.timezone);
    final range =
        '${formatPublicTime(appointment.startAt, appointment.timezone)}–'
        '${formatPublicTime(appointment.endAt, appointment.timezone)}';
    final minutes = appointment.endAt.difference(appointment.startAt).inMinutes;
    return InkSlotCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              color: InkSlotColors.bone,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  parts.monthShort.toUpperCase(),
                  style: inkSlotMono(size: 9, color: InkSlotColors.ink),
                ),
                Text(
                  '${parts.day}',
                  style: inkSlotSerif(30, color: InkSlotColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${publicCapitalize(parts.weekdayShort)} · $range',
                  style: const TextStyle(
                    color: InkSlotColors.bone,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sesión de ${publicDurationShort(minutes)} · Dodogio',
                  style: const TextStyle(
                    color: InkSlotColors.ash,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _restrictionDays(List<int>? weekdays) {
  if (weekdays == null || weekdays.isEmpty) return 'Flexible';
  const labels = <String>['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  final selected = weekdays.toSet().toList()..sort();
  if (selected.length == 7) return 'Todos';
  final consecutive =
      selected.length > 2 &&
      [
        for (var i = 1; i < selected.length; i++) selected[i] - selected[i - 1],
      ].every((gap) => gap == 1);
  if (consecutive) {
    return '${labels[selected.first]} – ${labels[selected.last]}';
  }
  return selected.map((day) => labels[day]).join(' · ');
}
