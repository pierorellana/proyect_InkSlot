import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/booking_request.dart';

class LinkReadyPage extends StatefulWidget {
  const LinkReadyPage({required this.link, super.key, this.onBack});

  final LinkReadyData link;
  final VoidCallback? onBack;

  @override
  State<LinkReadyPage> createState() => _LinkReadyPageState();
}

class _LinkReadyPageState extends State<LinkReadyPage> {
  bool _copied = false;
  bool _sharing = false;

  String get _url {
    final base = Uri.base;
    final hasWebOrigin = base.scheme == 'http' || base.scheme == 'https';
    final origin = hasWebOrigin ? base.origin : 'http://localhost';
    return '$origin${widget.link.path}';
  }

  Future<void> _copy() async {
    if (!mounted) return;
    setState(() => _copied = true);
    try {
      await Clipboard.setData(ClipboardData(text: _url));
    } on Object {
      // The visual state remains useful when the browser denies clipboard access.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles.')),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final result = await SharePlus.instance.share(ShareParams(text: _url));
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copia el enlace para compartirlo.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el menú de compartir.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                onPressed: widget.onBack,
                tooltip: 'Volver a solicitudes',
                icon: const Icon(Icons.arrow_back),
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 38),
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: InkSlotColors.tobacco,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Icon(
                      Icons.link_rounded,
                      color: InkSlotColors.copperLight,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: InkSlotMonoLabel(
                  'Solicitud creada · enlace privado',
                  color: InkSlotColors.copperLight,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tu enlace está listo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Compártelo con tu cliente para que elija una fecha dentro de las restricciones que definiste.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: InkSlotColors.surface,
                  borderRadius: BorderRadius.circular(InkSlotRadii.card),
                  border: Border.all(color: InkSlotColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const InkSlotLogo(size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Enlace de reserva',
                            style: TextStyle(
                              color: InkSlotColors.cream,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Vence ${_formatExpiry(widget.link.expiresAt)}',
                          style: const TextStyle(
                            color: InkSlotColors.warningText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      textField: true,
                      label: 'Enlace privado de reserva',
                      child: SelectableText(
                        _url,
                        style: const TextStyle(
                          color: InkSlotColors.copperLight,
                          fontFamily: 'Geist Mono',
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                      label: Text(_copied ? 'Copiado' : 'Copiar enlace'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: InkSlotColors.copperLight,
                        side: const BorderSide(color: InkSlotColors.lineStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkSlotPrimaryButton(
                label: _sharing ? 'Abriendo compartir…' : 'Compartir enlace',
                onPressed: _sharing ? null : _share,
                trailing: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: InkSlotColors.ink,
                        ),
                      )
                    : const Icon(Icons.ios_share_outlined, size: 20),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Volver a solicitudes'),
              ),
              if (!reducedMotion) const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    return content;
  }
}

String _formatExpiry(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')} · '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
