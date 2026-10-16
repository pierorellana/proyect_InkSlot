import 'package:url_launcher/url_launcher.dart';

/// Abre [url] fuera de la app (navegador o app nativa). Devuelve `false` si
/// el sistema no pudo abrirlo.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
