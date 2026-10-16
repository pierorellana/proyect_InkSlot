import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/external_link.dart';
import '../../../core/widgets/inkslot_kit.dart';

const publicStudioUrl = 'https://www.instagram.com/dodogioo';

/// Abre la cuenta de Instagram del estudio; si el sistema no puede, copia el
/// enlace y avisa con un toast.
Future<void> contactPublicStudio(BuildContext context) async {
  if (await openExternalLink(publicStudioUrl)) return;
  await Clipboard.setData(const ClipboardData(text: publicStudioUrl));
  if (context.mounted) {
    showInkSlotToast(context, 'Enlace del estudio copiado');
  }
}
