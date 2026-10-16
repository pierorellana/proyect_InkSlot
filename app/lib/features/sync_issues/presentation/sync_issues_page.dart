import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final initialLoading =
          controller.status == SyncIssuesListStatus.loading &&
          controller.items.isEmpty;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InkSlotMonoLabel('Sincronización'),
                const SizedBox(height: 14),
                Text(
                  'Incidencias',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 9),
                const Text(
                  'Revisa y reintenta operaciones pendientes de Calendar.',
                  style: TextStyle(color: InkSlotColors.secondary),
                ),
                const SizedBox(height: 26),
                _FilterBar(
                  selected: controller.filter,
                  onChanged: controller.setFilter,
                ),
                const SizedBox(height: 20),
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
                  if (controller.errorMessage != null)
                    _InlineError(
                      message: controller.errorMessage!,
                      onRetry: () => controller.load(refresh: true),
                    ),
                  if (controller.errorMessage != null)
                    const SizedBox(height: 14),
                  ...controller.items.map(
                    (issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _IssueCard(
                        issue: issue,
                        retrying: controller.retryingId == issue.id,
                        onRetry: issue.status == SyncIssueStatus.open
                            ? () => controller.retry(issue.id)
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final SyncIssueStatus selected;
  final ValueChanged<SyncIssueStatus> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _FilterButton(
        label: 'Abiertas',
        selected: selected == SyncIssueStatus.open,
        onTap: () => onChanged(SyncIssueStatus.open),
      ),
      _FilterButton(
        label: 'Resueltas',
        selected: selected == SyncIssueStatus.resolved,
        onTap: () => onChanged(SyncIssueStatus.resolved),
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
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: selected
          ? InkSlotColors.copperLight
          : InkSlotColors.secondary,
      backgroundColor: selected ? InkSlotColors.tobacco : Colors.transparent,
      side: BorderSide(
        color: selected ? InkSlotColors.copper : InkSlotColors.line,
      ),
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Text(label),
  );
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  issue.status == SyncIssueStatus.open
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: issue.status == SyncIssueStatus.open
                      ? InkSlotColors.warning
                      : InkSlotColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    issue.message,
                    style: const TextStyle(
                      color: InkSlotColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${issue.code} · ${issue.operation}',
              style: const TextStyle(
                color: InkSlotColors.secondary,
                fontFamily: 'Geist Mono',
                fontSize: 12,
              ),
            ),
          ],
        );
        final action = onRetry == null
            ? const SizedBox.shrink()
            : SizedBox(
                width: compact ? double.infinity : 150,
                child: InkSlotPrimaryButton(
                  label: retrying ? 'Reintentando…' : 'Reintentar',
                  onPressed: retrying ? null : onRetry,
                ),
              );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  if (onRetry != null) ...[const SizedBox(height: 14), action],
                ],
              )
            : Row(
                children: [
                  Expanded(child: content),
                  if (onRetry != null) ...[const SizedBox(width: 16), action],
                ],
              );
      },
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      3,
      (index) => Container(
        height: 104,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: InkSlotColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: InkSlotColors.line),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 52),
    child: Center(
      child: Text(
        'No hay incidencias en este estado.',
        style: TextStyle(color: InkSlotColors.secondary),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(message, style: const TextStyle(color: InkSlotColors.error)),
      const SizedBox(height: 14),
      InkSlotPrimaryButton(label: 'Reintentar', onPressed: onRetry),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: InkSlotColors.error.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: InkSlotColors.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
