import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';
import 'booking_requests_controller.dart';
import 'widgets/booking_request_card.dart';

enum _RequestFilter { pending, booked, expired, cancelled }

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({required this.controller, super.key});

  final BookingRequestsController controller;

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  _RequestFilter _filter = _RequestFilter.pending;
  bool _didLoad = false;

  BookingRequestsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoad) return;
      _didLoad = true;
      controller.load(status: _apiStatus(_filter));
    });
  }

  Future<void> _changeFilter(_RequestFilter filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    if (_isTerminal(filter)) {
      await controller.clearStatusFilter();
    } else {
      await controller.load(refresh: true, status: _apiStatus(filter));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final items = controller.items.where(_isVisible).toList(growable: false);
      final hasItems = controller.items.isNotEmpty;
      final initialLoading =
          controller.listStatus == BookingRequestsListStatus.loading &&
          !hasItems;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onCreate: () => context.go('/admin/requests/new')),
                const SizedBox(height: 30),
                _FilterBar(selected: _filter, onChanged: _changeFilter),
                const SizedBox(height: 20),
                if (initialLoading)
                  const _LoadingList()
                else if (controller.listStatus ==
                        BookingRequestsListStatus.error &&
                    !hasItems)
                  _ErrorState(
                    message:
                        controller.listError ??
                        'No se pudieron cargar las solicitudes.',
                    onRetry: () => controller.load(
                      refresh: true,
                      status: _apiStatus(_filter),
                    ),
                  )
                else if (items.isEmpty)
                  _EmptyState(
                    filter: _filter,
                    onCreate: () => context.go('/admin/requests/new'),
                    canLoadMore: controller.nextCursor != null,
                  )
                else ...[
                  if (controller.listError != null) ...[
                    _InlineError(
                      message: controller.listError!,
                      onRetry: () => controller.load(
                        refresh: true,
                        status: _apiStatus(_filter),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = items[index];
                      return BookingRequestCard(
                        request: request,
                        onTap: () =>
                            context.go('/admin/requests/${request.id}'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (controller.nextCursor != null)
                    _LoadMoreButton(
                      loading:
                          controller.listStatus ==
                          BookingRequestsListStatus.loading,
                      onPressed:
                          controller.listStatus ==
                              BookingRequestsListStatus.loading
                          ? null
                          : controller.loadMore,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  bool _isVisible(BookingRequest request) {
    return switch (_filter) {
      _RequestFilter.pending => request.status == BookingRequestStatus.pending,
      _RequestFilter.booked => request.status == BookingRequestStatus.booked,
      _RequestFilter.expired => request.status == BookingRequestStatus.expired,
      _RequestFilter.cancelled =>
        request.status == BookingRequestStatus.cancelled ||
            request.status == BookingRequestStatus.closed,
    };
  }

  bool _isTerminal(_RequestFilter filter) => filter == _RequestFilter.cancelled;

  BookingRequestStatus? _apiStatus(_RequestFilter filter) => switch (filter) {
    _RequestFilter.pending => BookingRequestStatus.pending,
    _RequestFilter.booked => BookingRequestStatus.booked,
    _RequestFilter.expired => BookingRequestStatus.expired,
    // The API has separate cancelled/closed filters. Load the unfiltered page
    // so the prototype can keep one terminal “Canceladas” tab.
    _RequestFilter.cancelled => null,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InkSlotMonoLabel('Espacio de trabajo'),
          const SizedBox(height: 14),
          Text('Solicitudes', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 9),
          const Text(
            'Gestiona los espacios que tus clientes pueden reservar.',
            style: TextStyle(color: InkSlotColors.secondary),
          ),
        ],
      );
      final action = compact
          ? IconButton.filled(
              onPressed: onCreate,
              tooltip: 'Nueva solicitud',
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: InkSlotColors.copper,
                foregroundColor: InkSlotColors.ink,
                minimumSize: const Size(48, 48),
              ),
            )
          : SizedBox(
              width: 280,
              child: InkSlotPrimaryButton(
                label: 'Nueva solicitud',
                onPressed: onCreate,
                trailing: const Icon(Icons.add, size: 19),
              ),
            );
      if (compact) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            action,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: title),
          const SizedBox(width: 20),
          action,
        ],
      );
    },
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final _RequestFilter selected;
  final ValueChanged<_RequestFilter> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _FilterButton(
        label: 'Pendientes',
        selected: selected == _RequestFilter.pending,
        onTap: () => onChanged(_RequestFilter.pending),
      ),
      _FilterButton(
        label: 'Agendadas',
        selected: selected == _RequestFilter.booked,
        onTap: () => onChanged(_RequestFilter.booked),
      ),
      _FilterButton(
        label: 'Vencidas',
        selected: selected == _RequestFilter.expired,
        onTap: () => onChanged(_RequestFilter.expired),
      ),
      _FilterButton(
        label: 'Canceladas',
        selected: selected == _RequestFilter.cancelled,
        onTap: () => onChanged(_RequestFilter.cancelled),
      ),
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Filtrar por $label',
    child: Material(
      color: selected ? InkSlotColors.tobacco : Colors.transparent,
      borderRadius: BorderRadius.circular(InkSlotRadii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InkSlotRadii.chip),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: InkSlotSpacing.minimumTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? InkSlotColors.copper : InkSlotColors.line,
            ),
            borderRadius: BorderRadius.circular(InkSlotRadii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? InkSlotColors.copperLight
                  : InkSlotColors.secondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      3,
      (index) => Padding(
        padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
        child: Container(
          height: 136,
          decoration: BoxDecoration(
            color: InkSlotColors.surface,
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: InkSlotColors.line),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.onCreate,
    required this.canLoadMore,
  });

  final _RequestFilter filter;
  final VoidCallback onCreate;
  final bool canLoadMore;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.inbox_outlined,
          size: 38,
          color: InkSlotColors.copperLight,
        ),
        const SizedBox(height: 18),
        Text(
          canLoadMore ? 'Sigue buscando' : _emptyTitle(filter),
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          canLoadMore
              ? 'Hay más solicitudes por cargar.'
              : _emptyDescription(filter),
          style: const TextStyle(color: InkSlotColors.secondary),
          textAlign: TextAlign.center,
        ),
        if (!canLoadMore && filter == _RequestFilter.pending) ...[
          const SizedBox(height: 22),
          SizedBox(
            width: 260,
            child: InkSlotPrimaryButton(
              label: 'Nueva solicitud',
              onPressed: onCreate,
              trailing: const Icon(Icons.add, size: 19),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF241614),
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.error.withValues(alpha: .35)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          color: InkSlotColors.errorText,
          size: 34,
        ),
        const SizedBox(height: 14),
        const Text(
          'No pudimos cargar tus solicitudes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: InkSlotColors.secondary),
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
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
    child: Material(
      color: const Color(0xFF241614),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: InkSlotColors.errorText,
              size: 19,
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
            IconButton(
              onPressed: onRetry,
              tooltip: 'Reintentar',
              icon: const Icon(Icons.refresh, size: 19),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more),
      label: Text(loading ? 'Cargando…' : 'Cargar más'),
      style: OutlinedButton.styleFrom(
        foregroundColor: InkSlotColors.copperLight,
        side: const BorderSide(color: InkSlotColors.lineStrong),
        minimumSize: const Size(160, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}

String _emptyTitle(_RequestFilter filter) => switch (filter) {
  _RequestFilter.pending => 'No tienes solicitudes pendientes',
  _RequestFilter.booked => 'No tienes solicitudes agendadas',
  _RequestFilter.expired => 'No tienes solicitudes vencidas',
  _RequestFilter.cancelled => 'No tienes solicitudes canceladas',
};

String _emptyDescription(_RequestFilter filter) => switch (filter) {
  _RequestFilter.pending =>
    'Crea una solicitud para compartir un enlace privado con tu cliente.',
  _RequestFilter.booked =>
    'Las solicitudes que tus clientes agenden aparecerán aquí.',
  _RequestFilter.expired =>
    'Los enlaces que superen su fecha límite aparecerán aquí.',
  _RequestFilter.cancelled =>
    'Las solicitudes revocadas o cerradas aparecerán aquí.',
};
