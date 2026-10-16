import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/sync_issue.dart';
import 'sync_issues_controller.dart';

class SyncIssuesPage extends StatefulWidget {
  const SyncIssuesPage({required this.controller, super.key});

  final SyncIssuesController controller;

  @override
  State<SyncIssuesPage> createState() => _SyncIssuesPageState();
}

class _SyncIssuesPageState extends State<SyncIssuesPage> {
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoad) return;
      _didLoad = true;
      widget.controller.load();
    });
  }

  Future<void> _retry(String id) async {
    await widget.controller.retry(id);
    if (!mounted || widget.controller.errorMessage != null) return;
    showInkSlotToast(context, 'Evento creado en Google Calendar');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top < 58 ? 58.0 : media.padding.top;
    return InkSlotScreenIn(
      duration: const Duration(milliseconds: 550),
      offset: 14,
      fromScale: 1,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final initialLoading =
              controller.status == SyncIssuesListStatus.loading &&
              controller.items.isEmpty;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              topInset,
              20,
              40 + media.padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkSlotIconButton(
                    icon: InkSlotIcons.volver,
                    semanticLabel: 'Volver',
                    onPressed: () => context.go('/admin'),
                  ),
                ),
                const SizedBox(height: 22),
                InkSlotRise(
                  duration: const Duration(milliseconds: 650),
                  offset: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SINCRONIZACIÓN',
                        style: inkSlotMono(color: InkSlotColors.tertiary),
                      ),
                      const SizedBox(height: 8),
                      Text('Incidencias', style: inkSlotSerif(42)),
                      const SizedBox(height: 10),
                      const Text(
                        'Revisa y reintenta operaciones pendientes de Calendar.',
                        style: TextStyle(
                          color: Color(0xFF9B968E),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                InkSlotRise(
                  delay: const Duration(milliseconds: 60),
                  duration: const Duration(milliseconds: 650),
                  offset: 16,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InkSlotChip(
                        label: 'Abiertas',
                        selected: controller.filter == SyncIssueStatus.open,
                        onTap: () => controller.setFilter(SyncIssueStatus.open),
                      ),
                      InkSlotChip(
                        label: 'Resueltas',
                        selected: controller.filter == SyncIssueStatus.resolved,
                        onTap: () =>
                            controller.setFilter(SyncIssueStatus.resolved),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (initialLoading)
                  const _LoadingState()
                else if (controller.status == SyncIssuesListStatus.error &&
                    controller.items.isEmpty)
                  _ErrorState(
                    message:
                        controller.errorMessage ??
                        'No se pudieron cargar las incidencias.',
                    onRetry: () => controller.load(refresh: true),
                  )
                else if (controller.items.isEmpty)
                  const _EmptyState()
                else ...[
                  if (controller.errorMessage != null) ...[
                    _InlineError(
                      message: controller.errorMessage!,
                      onRetry: () => controller.load(refresh: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final issue in controller.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _IssueCard(
                        issue: issue,
                        retrying: controller.retryingId == issue.id,
                        onRetry: issue.status == SyncIssueStatus.open
                            ? () => _retry(issue.id)
                            : null,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.issue,
    required this.retrying,
    required this.onRetry,
  });

  final SyncIssue issue;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final open = issue.status == SyncIssueStatus.open;
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: open ? InkSlotColors.warning : InkSlotColors.success,
        shape: BoxShape.circle,
      ),
    );
    return InkSlotCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: open ? InkSlotPulse(minOpacity: .35, child: dot) : dot,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.message,
                      style: const TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${issue.code} · ${issue.operation}',
                      style: const TextStyle(
                        color: InkSlotColors.ash,
                        fontFamily: 'Geist Mono',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!open) ...[
                const SizedBox(width: 12),
                const InkSlotPill('Resuelta', tone: InkSlotPillTone.ok),
              ],
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            InkSlotPrimaryButton(
              label: retrying ? 'Reintentando…' : 'Reintentar ahora',
              loading: retrying,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => InkSlotPulse(
    minOpacity: .5,
    child: Column(
      children: List.generate(
        3,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: InkSlotCard(
            child: SizedBox(height: 104, width: double.infinity),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const InkSlotCard(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 36),
    child: Text(
      'No hay incidencias en este estado.',
      textAlign: TextAlign.center,
      style: TextStyle(color: InkSlotColors.tertiary, fontSize: 14),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    padding: const EdgeInsets.all(22),
    borderColor: const Color(0x40E2604C),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: const TextStyle(color: InkSlotColors.errorText)),
        const SizedBox(height: 18),
        InkSlotPrimaryButton(label: 'Reintentar', onPressed: onRetry),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
    color: const Color(0x14E2604C),
    borderColor: const Color(0x40E2604C),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: InkSlotColors.errorText,
              fontSize: 14,
            ),
          ),
        ),
        InkSlotPress(
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Reintentar',
              style: TextStyle(color: InkSlotColors.bone, fontSize: 14),
            ),
          ),
        ),
      ],
    ),
  );
}
