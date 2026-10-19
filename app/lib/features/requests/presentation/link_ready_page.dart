import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../admin/presentation/admin_date_format.dart';
import '../../admin/presentation/admin_motion.dart';
import '../domain/booking_request.dart';

/// Datos de la pantalla "enlace listo": el enlace más el contexto de la solicitud.
class LinkReadyArgs {
  const LinkReadyArgs({
    required this.link,
    this.clientName,
    this.durationMinutes,
  });

  final LinkReadyData link;
  final String? clientName;
  final int? durationMinutes;
}

class LinkReadyPage extends StatefulWidget {
  const LinkReadyPage({
    required this.link,
    super.key,
    this.onBack,
    this.clientName,
    this.durationMinutes,
  });

  final LinkReadyData link;
  final VoidCallback? onBack;
  final String? clientName;
  final int? durationMinutes;

  @override
  State<LinkReadyPage> createState() => _LinkReadyPageState();
}

class _LinkReadyPageState extends State<LinkReadyPage> {
  bool _copied = false;
  Timer? _copiedTimer;

  String get _url {
    final base = Uri.base;
    final hasWebOrigin = base.scheme == 'http' || base.scheme == 'https';
    final origin = hasWebOrigin ? base.origin : 'http://localhost';
    // Flutter Web uses hash-based navigation in this build. Without the hash,
    // opening a generated link loads `/`, whose local demo redirect points to
    // the fixed `demo-token` fixture instead of this request's token.
    return '$origin/#${widget.link.path}';
  }

  String get _displayUrl => _url.replaceFirst(RegExp(r'^https?://'), '');

  String? get _firstName {
    final name = widget.clientName?.trim() ?? '';
    return name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _copied = false);
    });
    try {
      await Clipboard.setData(ClipboardData(text: _url));
    } on Object {
      // The visual state remains useful when the browser denies clipboard access.
    }
    if (!mounted) return;
    showInkSlotToast(context, 'Enlace copiado');
  }

  Future<void> _share() async {
    try {
      final result = await SharePlus.instance.share(ShareParams(text: _url));
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        showInkSlotToast(
          context,
          'Copia el enlace para compartirlo',
          icon: InkSlotIcons.alerta,
        );
      } else if (result.status == ShareResultStatus.success) {
        showInkSlotToast(context, 'Enlace compartido');
      }
    } on Object {
      if (mounted) {
        showInkSlotToast(
          context,
          'No se pudo abrir el menú de compartir',
          icon: InkSlotIcons.alerta,
        );
      }
    }
  }

  Future<void> _openShareSheet() async {
    final first = _firstName;
    final pick = await showInkSlotSheet<bool>(
      context: context,
      builder: (sheetContext) => _ShareSheet(
        title: first == null ? 'Compartir enlace' : 'Compartir con $first',
        onPick: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (pick == true && mounted) await _share();
  }

  String get _validity {
    final hours =
        (widget.link.expiresAt.difference(DateTime.now()).inMinutes / 60)
            .round()
            .clamp(0, 9999);
    final duration = widget.durationMinutes;
    return [
      'Vence en $hours h',
      if (duration != null) durationLabel(duration),
      'un solo uso',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top < 58 ? 58.0 : media.padding.top;
    final first = _firstName;
    return ColoredBox(
      color: InkSlotColors.ink,
      child: AdminScaleIn(
        duration: const Duration(milliseconds: 550),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  topInset,
                  24,
                  media.padding.bottom + 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkSlotIconButton(
                        icon: InkSlotIcons.cerrar,
                        semanticLabel: 'Cerrar',
                        onPressed: widget.onBack,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AdminChain(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: InkSlotColors.copper,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x99C87939),
                                blurRadius: 50,
                                spreadRadius: -16,
                                offset: Offset(0, 20),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const InkSlotIcon(
                            InkSlotIcons.enlace,
                            size: 40,
                            color: InkSlotColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AdminScaleRise(
                      delay: const Duration(milliseconds: 120),
                      duration: const Duration(milliseconds: 650),
                      child: Text(
                        'SOLICITUD CREADA · PENDIENTE DE AGENDAR',
                        style: inkSlotMono(color: InkSlotColors.successText),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminScaleRise(
                      delay: const Duration(milliseconds: 180),
                      duration: const Duration(milliseconds: 650),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Enlace listo para '),
                            TextSpan(
                              text: '${first ?? 'tu cliente'}.',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        style: inkSlotSerif(44),
                      ),
                    ),
                    const SizedBox(height: 26),
                    AdminScaleRise(
                      delay: const Duration(milliseconds: 240),
                      duration: const Duration(milliseconds: 650),
                      child: InkSlotCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AdminTok(
                              child: Semantics(
                                label: 'Enlace privado de reserva',
                                child: SelectableText(
                                  _displayUrl,
                                  style: const TextStyle(
                                    fontFamily: 'Geist Mono',
                                    fontSize: 15,
                                    color: InkSlotColors.bone,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _validity,
                              style: const TextStyle(
                                color: Color(0xFF9B968E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Spacer(),
                    InkSlotPrimaryButton(
                      label: _copied ? 'Copiado' : 'Copiar enlace',
                      leading: _copied
                          ? const InkSlotIcon(InkSlotIcons.check, size: 18)
                          : null,
                      onPressed: _copy,
                    ),
                    const SizedBox(height: 10),
                    InkSlotGhostButton(
                      label: 'Compartir',
                      onPressed: _openShareSheet,
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
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.title, required this.onPick});

  final String title;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: InkSlotColors.bone,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Se abre la app elegida con el mensaje listo.',
        style: TextStyle(color: Color(0xFF9B968E), fontSize: 14),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _ShareOption(
              icon: InkSlotIcons.mensaje,
              label: 'WhatsApp',
              onTap: onPick,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShareOption(
              icon: InkSlotIcons.camaraSocial,
              label: 'Instagram',
              onTap: onPick,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShareOption(
              icon: InkSlotIcons.compartir,
              label: 'Más',
              onTap: onPick,
            ),
          ),
        ],
      ),
    ],
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final InkSlotIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkSlotPress(
    onTap: onTap,
    child: InkSlotCard(
      child: SizedBox(
        height: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkSlotIcon(icon, size: 22, color: InkSlotColors.bone),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: InkSlotColors.bone, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
