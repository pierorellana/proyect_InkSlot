abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/v1',
  );

  static Uri get apiBaseUri {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      throw StateError('API_BASE_URL debe ser una URL absoluta válida.');
    }
    return uri;
  }
}
