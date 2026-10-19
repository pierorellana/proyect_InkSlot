import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_state_block.dart';
import '../../admin/presentation/admin_layout.dart';
import '../../admin/presentation/admin_motion.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';
import 'booking_requests_controller.dart';
import 'widgets/booking_request_card.dart';

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({required this.controller, super.key});

  final BookingRequestsController controller;

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  bool _didLoad = false;

  BookingRequestsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoad) return;
      _didLoad = true;
      controller.load(status: controller.filter.apiStatus);
    });
  }

  Future<void> _changeFilter(BookingRequestsFilter filter) async =>
      controller.setFilter(filter);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final items = controller.items
          .where((request) => _isVisible(request, controller.filter))
          .toList(growable: false);
      final hasItems = controller.items.isNotEmpty;
      final loading =
          controller.listStatus == BookingRequestsListStatus.loading;
      final initialLoading = loading && !hasItems;
      final filter = controller.filter;
      void reload() => controller.load(refresh: true, status: filter.apiStatus);
      final top = adminPageTopInset(context);
      return AdminScaleIn(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, top < 58 ? 58 : top, 20, 120),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminScaleRise.step(
                    0,
                    child: _Header(
                      onCreate: () => context.go('/admin/requests/new'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AdminScaleRise.step(
                    1,
                    child: _FilterBar(
                      selected: filter,
                      count: initialLoading || controller.listError != null
                          ? null
                          : items.length,
                      more: controller.nextCursor != null,
                      onChanged: _changeFilter,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (initialLoading)
                    const InkSlotSkeletonRows(count: 4)
                  else if (controller.listStatus ==
                          BookingRequestsListStatus.error &&
                      !hasItems)
                    InkSlotStateBlock(
                      icon: InkSlotIcons.sinConexion,
                      title: 'No pudimos cargar tus solicitudes.',
                      body:
                          controller.listError ??
                          'No se pudieron cargar las solicitudes.',
                      actionLabel: 'Reintentar',
                      onAction: reload,
                    )
                  else if (items.isEmpty)
                    InkSlotStateBlock(
                      icon: InkSlotIcons.enlace,
                      title: controller.nextCursor != null
                          ? 'Sigue buscando.'
                          : _emptyTitle(filter),
                      body: controller.nextCursor != null
                          ? 'Hay más solicitudes por cargar.'
                          : _emptyDescription(filter),
                      actionLabel: controller.nextCursor != null
                          ? 'Cargar más'
                          : filter == BookingRequestsFilter.pending
                          ? 'Nueva solicitud'
                          : null,
                      onAction: controller.nextCursor != null
                          ? controller.loadMore
                          : () => context.go('/admin/requests/new'),
                    )
                  else ...[
                    if (controller.listError != null) ...[
                      _InlineError(
                        message: controller.listError!,
                        onRetry: reload,
                      ),
                      const SizedBox(height: 14),
                    ],
                    AdminScaleRise.step(
                      2,
                      child: InkSlotCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const InkSlotSep(indent: 0),
                              BookingRequestCard(
                                request: items[i],
                                onTap: () => context.go(
                                  '/admin/requests/${items[i].id}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (controller.nextCursor != null) ...[
                      const SizedBox(height: 16),
                      InkSlotGhostButton(
                        label: loading ? 'Cargando…' : 'Cargar más',
                        onPressed: loading ? null : controller.loadMore,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  bool _isVisible(BookingRequest request, BookingRequestsFilter filter) {
    return switch (filter) {
      BookingRequestsFilter.pending =>
        request.status == BookingRequestStatus.pending,
      BookingRequestsFilter.booked =>
        request.status == BookingRequestStatus.booked,
      BookingRequestsFilter.expired =>
        request.status == BookingRequestStatus.expired,
      BookingRequestsFilter.cancelled =>
        request.status == BookingRequestStatus.cancelled ||
            request.status == BookingRequestStatus.closed,
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Text('Solicitudes', style: inkSlotSerif(42))),
      InkSlotIconButton(
        icon: InkSlotIcons.mas,
        semanticLabel: 'Nueva solicitud',
        onPressed: onCreate,
      ),
    ],
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.count,
    required this.more,
    required this.onChanged,
  });

  final BookingRequestsFilter selected;
  final int? count;
  final bool more;
  final ValueChanged<BookingRequestsFilter> onChanged;

  static const _labels = {
    BookingRequestsFilter.pending: 'Pendientes',
    BookingRequestsFilter.booked: 'Agendadas',
    BookingRequestsFilter.expired: 'Vencidas',
    BookingRequestsFilter.cancelled: 'Canceladas',
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (final entry in _labels.entries) ...[
          if (entry.key != BookingRequestsFilter.pending)
            const SizedBox(width: 12),
          Semantics(
            selected: entry.key == selected,
            label: 'Filtrar por ${entry.value}',
            excludeSemantics: true,
            button: true,
            child: InkSlotChip(
              label: entry.value,
              selected: entry.key == selected,
              trailingCount: entry.key == selected && !more ? count : null,
              onTap: () => onChanged(entry.key),
            ),
          ),
        ],
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
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
          InkSlotIconButton(
            icon: InkSlotIcons.sincronizar,
            semanticLabel: 'Reintentar',
            onPressed: onRetry,
            color: InkSlotColors.errorText,
          ),
        ],
      ),
    ),
  );
}

String _emptyTitle(BookingRequestsFilter filter) => switch (filter) {
  BookingRequestsFilter.pending => 'Nada pendiente.',
  BookingRequestsFilter.booked => 'Nada agendado.',
  BookingRequestsFilter.expired => 'Nada vencido.',
  BookingRequestsFilter.cancelled => 'Nada cancelado.',
};

String _emptyDescription(BookingRequestsFilter filter) => switch (filter) {
  BookingRequestsFilter.pending =>
    'Crea una solicitud para compartir un enlace privado con tu cliente.',
  BookingRequestsFilter.booked =>
    'Las solicitudes que tus clientes agenden aparecerán aquí.',
  BookingRequestsFilter.expired =>
    'Los enlaces que superen su fecha límite aparecerán aquí.',
  BookingRequestsFilter.cancelled =>
    'Las solicitudes revocadas o cerradas aparecerán aquí.',
};
