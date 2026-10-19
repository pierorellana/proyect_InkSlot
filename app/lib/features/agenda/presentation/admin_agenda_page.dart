import 'package:flutter/material.dart';
import '../../../core/utils/external_link.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../../core/widgets/inkslot_state_block.dart';
import '../../admin/presentation/admin_motion.dart';
import '../domain/availability.dart';
import '../domain/calendar_status.dart';
import 'agenda_controller.dart';

class AdminAgendaPage extends StatefulWidget {
  const AdminAgendaPage({required this.controller, super.key});

  final AgendaController controller;

  @override
  State<AdminAgendaPage> createState() => _AdminAgendaPageState();
}

class _AdminAgendaPageState extends State<AdminAgendaPage> {
  AgendaController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.load(refresh: true);
    });
  }

  Future<void> _connect() async {
    final authorization = await controller.requestAuthorization();
    if (!mounted || authorization == null) return;
    await showInkSlotSheet<void>(
      context: context,
      builder: (_) => _AuthorizationSheet(authorization: authorization),
    );
    if (mounted) await controller.refreshCalendar();
  }

  Future<void> _disconnect() async {
    final confirmed = await showInkSlotSheet<bool>(
      context: context,
      builder: (sheetContext) => const _DisconnectSheet(),
    );
    if (confirmed != true || !mounted) return;
    final ok = await controller.disconnect();
    if (mounted && ok) {
      showInkSlotToast(context, 'Google Calendar desconectado');
    }
  }

  Future<void> _toggleDay(int weekday, bool open) async {
    final ok = await controller.setDayOpen(weekday, open);
    if (mounted && ok) showInkSlotToast(context, 'Jornada actualizada');
  }

  Future<void> _addBlock() async {
    final result = await showInkSlotSheet<_BlockDraft>(
      context: context,
      builder: (_) => const _BlockSheet(),
    );
    if (result == null || !mounted) return;
    final ok = await controller.addBlock(
      startAt: result.range.start,
      endAt: result.range.end.add(const Duration(days: 1)),
      reason: result.reason,
    );
    if (mounted && ok) showInkSlotToast(context, 'Fechas bloqueadas');
  }

  Future<void> _removeBlock(AvailabilityBlock block) async {
    final ok = await controller.removeBlock(block.id);
    if (mounted && ok) showInkSlotToast(context, 'Bloqueo eliminado');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top < 58 ? 58.0 : media.padding.top;
    return AdminScaleIn(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, top, 20, 120),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminScaleRise.step(
                    0,
                    child: Text('Agenda', style: inkSlotSerif(42)),
                  ),
                  ..._body(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    final status = controller.status;
    if (status == AgendaLoadStatus.idle || status == AgendaLoadStatus.loading) {
      return const [SizedBox(height: 22), _AgendaSkeleton()];
    }
    if (status == AgendaLoadStatus.error) {
      return [
        const SizedBox(height: 22),
        InkSlotStateBlock(
          icon: InkSlotIcons.sinConexion,
          title: 'No pudimos cargar tu agenda.',
          body: controller.errorMessage ?? 'No se pudo cargar tu agenda.',
          actionLabel: 'Reintentar',
          onAction: () => controller.load(refresh: true),
        ),
      ];
    }
    final availability = controller.effectiveAvailability;
    return [
      if (controller.actionError != null || controller.errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: _InlineError(
            message: controller.actionError ?? controller.errorMessage!,
          ),
        ),
      AdminScaleRise.step(
        1,
        child: Padding(
          padding: const EdgeInsets.only(top: 22),
          child: _CalendarCard(
            status: controller.calendar!,
            busy: controller.connecting,
            onConnect: _connect,
            onDisconnect: _disconnect,
          ),
        ),
      ),
      InkSlotSectionHeader(
        title: 'Jornada semanal',
        titleSize: 16,
        titleWeight: FontWeight.w600,
        trailing: Text(
          _gmt(DateTime.now().timeZoneOffset),
          style: inkSlotMono(size: 9, color: InkSlotColors.tertiary),
        ),
      ),
      InkSlotCard(
        child: Column(
          children: [
            for (var i = 0; i < _weekOrder.length; i++) ...[
              if (i > 0) const InkSlotSep(indent: 0),
              _DayRow(
                weekday: _weekOrder[i],
                windows: availability.windowsFor(_weekOrder[i]),
                busy: controller.savingWeek,
                onChanged: (open) => _toggleDay(_weekOrder[i], open),
              ),
            ],
          ],
        ),
      ),
      InkSlotSectionHeader(
        title: 'Descansos y bloqueos',
        titleSize: 16,
        titleWeight: FontWeight.w600,
        actionLabel: '+ Agregar',
        actionSize: 14,
        actionMinHeight: 44,
        onAction: controller.mutatingBlock ? null : _addBlock,
      ),
      InkSlotCard(
        child: controller.blocks.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Text(
                  'Sin bloqueos. Agrega vacaciones, feriados o descansos.',
                  style: TextStyle(
                    color: InkSlotColors.secondary,
                    fontSize: 14,
                  ),
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < controller.blocks.length; i++) ...[
                    if (i > 0) const InkSlotSep(),
                    _BlockRow(
                      block: controller.blocks[i],
                      onRemove: controller.mutatingBlock
                          ? null
                          : () => _removeBlock(controller.blocks[i]),
                    ),
                  ],
                ],
              ),
      ),
      const InkSlotSectionHeader(
        title: 'Reglas de reserva',
        titleSize: 16,
        titleWeight: FontWeight.w600,
      ),
      InkSlotCard(
        child: Column(
          children: [
            _RuleRow(
              'Intervalo de inicio',
              '${availability.slotStepMinutes} min',
            ),
            const InkSlotSep(),
            _RuleRow(
              'Anticipación mínima',
              '${availability.minimumNoticeHours} h',
            ),
            const InkSlotSep(),
            _RuleRow('Horizonte', '${availability.horizonDays} días'),
            const InkSlotSep(),
            _RuleRow(
              'Margen entre sesiones',
              '${availability.bufferMinutes} min',
            ),
            const InkSlotSep(),
            _RuleRow('Zona horaria', availability.timezone),
          ],
        ),
      ),
    ];
  }
}

const _weekOrder = [1, 2, 3, 4, 5, 6, 0];
const _dayNames = {
  0: 'Dom',
  1: 'Lun',
  2: 'Mar',
  3: 'Mié',
  4: 'Jue',
  5: 'Vie',
  6: 'Sáb',
};

String _gmt(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return 'GMT$sign$hours${rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}'}';
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.status,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
  });

  final CalendarStatus status;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final state = status.state;
    final (desc, pill, tone, cta) = switch (state) {
      CalendarConnectionState.connected => (
        status.calendarName == null
            ? 'Conectado a tu calendario.'
            : '«${status.calendarName}»',
        'Conectado',
        InkSlotPillTone.ok,
        null,
      ),
      CalendarConnectionState.needsReconnect => (
        'El permiso expiró. Reconecta para seguir validando horarios.',
        'Reconectar',
        InkSlotPillTone.cancelled,
        'Reconectar Google Calendar',
      ),
      CalendarConnectionState.error => (
        'No pudimos validar la conexión. Reconecta para seguir validando horarios.',
        'Error',
        InkSlotPillTone.cancelled,
        'Reconectar Google Calendar',
      ),
      CalendarConnectionState.disconnected => (
        'Sin conexión. No se ofrecen horarios hasta conectar.',
        'Desconectado',
        InkSlotPillTone.cancelled,
        'Conectar Google Calendar',
      ),
    };
    return InkSlotCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: InkSlotColors.surfaceTwo,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const InkSlotIcon(
                  InkSlotIcons.calendario,
                  size: 20,
                  color: InkSlotColors.bone,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Calendar',
                      style: TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: InkSlotColors.ash,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkSlotPill(pill, tone: tone),
            ],
          ),
          const SizedBox(height: 14),
          if (state == CalendarConnectionState.connected)
            Align(
              alignment: Alignment.centerLeft,
              child: InkSlotPress(
                onTap: busy ? null : onDisconnect,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy) ...[
                        const InkSlotSpinner(size: 14),
                        const SizedBox(width: 8),
                      ],
                      const Text(
                        'Desconectar',
                        style: TextStyle(
                          color: InkSlotColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 48,
              child: InkSlotPrimaryButton(
                label: cta!,
                loading: busy,
                onPressed: onConnect,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.windows,
    required this.busy,
    required this.onChanged,
  });

  final int weekday;
  final List<WeeklyWindow> windows;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final open = windows.isNotEmpty;
    final name = _dayNames[weekday]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              name,
              style: const TextStyle(
                color: InkSlotColors.bone,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              open
                  ? windows
                        .map((w) => '${w.startLocal} - ${w.endLocal}')
                        .join(' · ')
                  : 'Cerrado',
              style: TextStyle(
                fontFamily: 'Geist Mono',
                fontSize: 13,
                color: open ? InkSlotColors.bone : InkSlotColors.tertiary,
              ),
            ),
          ),
          InkSlotSwitch(
            value: open,
            semanticLabel: '$name ${open ? 'abierto' : 'cerrado'}',
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.onRemove});

  final AvailabilityBlock block;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Expanded(
            child: Text(
              block.reason == null || block.reason!.isEmpty
                  ? 'Bloqueo'
                  : block.reason!,
              style: const TextStyle(color: InkSlotColors.bone, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatBlockRange(block.startAt, block.endAt),
            style: const TextStyle(
              fontFamily: 'Geist Mono',
              fontSize: 13,
              color: InkSlotColors.secondary,
            ),
          ),
          InkSlotIconButton(
            icon: InkSlotIcons.cerrar,
            semanticLabel: 'Eliminar bloqueo',
            iconSize: 14,
            background: Colors.transparent,
            borderColor: Colors.transparent,
            color: InkSlotColors.tertiary,
            onPressed: onRemove,
          ),
        ],
      ),
    ),
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: InkSlotColors.bone, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0x24E2604C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const InkSlotIcon(
            InkSlotIcons.alerta,
            size: 20,
            color: InkSlotColors.errorText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: InkSlotColors.errorText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AgendaSkeleton extends StatelessWidget {
  const _AgendaSkeleton();

  @override
  Widget build(BuildContext context) => const InkSlotSkeletonRows(count: 4);
}

class _AuthorizationSheet extends StatelessWidget {
  const _AuthorizationSheet({required this.authorization});

  final CalendarAuthorization authorization;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Conectar Google Calendar', style: inkSlotSerif(32, height: 1.02)),
      const SizedBox(height: 10),
      const Text(
        'Ábrelo en tu navegador y autoriza el acceso a tu cuenta de Google. '
        'Vence en pocos minutos.',
        style: TextStyle(
          color: InkSlotColors.secondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: InkSlotColors.field,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          authorization.url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Geist Mono',
            fontSize: 12,
            color: InkSlotColors.secondary,
          ),
        ),
      ),
      const SizedBox(height: 18),
      InkSlotPrimaryButton(
        label: 'Abrir Google Calendar',
        onPressed: () async {
          if (await openExternalLink(authorization.url)) return;
          if (!context.mounted) return;
          await Clipboard.setData(ClipboardData(text: authorization.url));
          if (context.mounted) {
            showInkSlotToast(context, 'No se pudo abrir; enlace copiado');
          }
        },
      ),
      const SizedBox(height: 10),
      InkSlotGhostButton(
        label: 'Copiar enlace',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: authorization.url));
          if (context.mounted) showInkSlotToast(context, 'Enlace copiado');
        },
      ),
      const SizedBox(height: 10),
      InkSlotGhostButton(
        label: 'Ya autoricé',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

class _DisconnectSheet extends StatelessWidget {
  const _DisconnectSheet();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '¿Desconectar Google Calendar?',
        style: inkSlotSerif(32, height: 1.02),
      ),
      const SizedBox(height: 10),
      const Text(
        'No se ofrecen horarios nuevos hasta que lo vuelvas a conectar. '
        'Tus citas se conservan.',
        style: TextStyle(
          color: InkSlotColors.secondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 22),
      InkSlotDangerButton(
        label: 'Desconectar',
        onPressed: () => Navigator.of(context).pop(true),
      ),
      const SizedBox(height: 10),
      InkSlotGhostButton(
        label: 'Mantener conexión',
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
}

class _BlockDraft {
  const _BlockDraft(this.reason, this.range);

  final String reason;
  final DateTimeRange range;
}

class _BlockSheet extends StatefulWidget {
  const _BlockSheet();

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  static const _reasons = ['Vacaciones', 'Feriado', 'Personal'];

  String _reason = _reasons.first;
  int _preset = 1;
  DateTimeRange? _custom;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  late final List<(String, DateTimeRange)> _presets = () {
    final today = _today;
    final saturday = today.add(
      Duration(
        days: (DateTime.saturday - today.weekday) % 7 == 0
            ? 7
            : (DateTime.saturday - today.weekday) % 7,
      ),
    );
    return <(String, DateTimeRange)>[
      ('Hoy', DateTimeRange(start: today, end: today)),
      (
        'Mañana',
        DateTimeRange(
          start: today.add(const Duration(days: 1)),
          end: today.add(const Duration(days: 1)),
        ),
      ),
      ('Próximo sábado', DateTimeRange(start: saturday, end: saturday)),
      (
        'Próximos 7 días',
        DateTimeRange(start: today, end: today.add(const Duration(days: 6))),
      ),
    ];
  }();

  DateTimeRange get _range => _custom ?? _presets[_preset].$2;

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 730)),
      helpText: 'Fechas a bloquear',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      saveText: 'Listo',
    );
    if (picked != null && mounted) setState(() => _custom = picked);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Nuevo bloqueo', style: inkSlotSerif(32, height: 1.02)),
      const SizedBox(height: 16),
      const Text(
        'Motivo',
        style: TextStyle(color: InkSlotColors.secondary, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final reason in _reasons)
            InkSlotChip(
              label: reason,
              selected: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Fechas',
        style: TextStyle(color: InkSlotColors.secondary, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _presets.length; i++)
            InkSlotChip(
              label: _presets[i].$1,
              selected: _custom == null && _preset == i,
              onTap: () => setState(() {
                _preset = i;
                _custom = null;
              }),
            ),
          InkSlotChip(
            label: _custom == null
                ? 'Elegir fechas'
                : formatBlockRange(
                    _custom!.start,
                    _custom!.end.add(const Duration(days: 1)),
                  ),
            selected: _custom != null,
            onTap: _pickCustom,
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'Los clientes con enlace activo dejarán de ver esos días al instante.',
        style: TextStyle(color: InkSlotColors.ash, fontSize: 13),
      ),
      const SizedBox(height: 16),
      InkSlotPrimaryButton(
        label: 'Bloquear fechas',
        onPressed: () =>
            Navigator.of(context).pop(_BlockDraft(_reason, _range)),
      ),
    ],
  );
}

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _weekdayShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String _hm(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

bool _isMidnight(DateTime date) => date.hour == 0 && date.minute == 0;

/// Formato del prototipo: `sáb 31 oct`, `21 – 28 dic`, `31 dic – 2 ene`.
String formatBlockRange(DateTime startAt, DateTime endAt) {
  final start = startAt.toLocal();
  final end = endAt.toLocal();
  if (_isMidnight(start) && _isMidnight(end)) {
    final last = end.subtract(const Duration(days: 1));
    if (last.year == start.year &&
        last.month == start.month &&
        last.day == start.day) {
      return '${_weekdayShort[start.weekday - 1]} ${start.day} '
          '${_months[start.month - 1]}';
    }
    if (last.month == start.month && last.year == start.year) {
      return '${start.day} – ${last.day} ${_months[start.month - 1]}';
    }
    return '${start.day} ${_months[start.month - 1]} – '
        '${last.day} ${_months[last.month - 1]}';
  }
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${_weekdayShort[start.weekday - 1]} ${start.day} '
        '${_months[start.month - 1]} · ${_hm(start)} – ${_hm(end)}';
  }
  return '${start.day} ${_months[start.month - 1]} ${_hm(start)} – '
      '${end.day} ${_months[end.month - 1]} ${_hm(end)}';
}
