import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'http_client_factory.dart';

abstract class ApiClient {
  Future<Map<String, dynamic>> getJson(String path);

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });
}

class HttpApiClient implements ApiClient {
  HttpApiClient({http.Client? client, Uri? baseUri})
    : _client = client ?? createHttpClient(),
      _baseUri = baseUri ?? AppConfig.apiBaseUri;

  final http.Client _client;
  final Uri _baseUri;

  @override
  Future<Map<String, dynamic>> getJson(String path) =>
      _request(method: 'GET', path: path);

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) => _request(method: 'POST', path: path, body: body, headers: headers);

  void close() => _client.close();

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(method, _buildUri(path));
    request.headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (headers != null) request.headers.addAll(headers);

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } on http.ClientException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'No se pudo conectar con el servidor.',
      );
    } on Object {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'No se pudo conectar con el servidor.',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toApiException(response.statusCode, decoded);
    }

    return decoded;
  }

  Uri _buildUri(String path) {
    final basePath = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final requestPath = path.replaceFirst(RegExp(r'^/+'), '');

    return _baseUri.replace(path: '$basePath/$requestPath');
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'El servidor devolvió una respuesta inválida.',
      );
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const ApiException(
      code: 'INVALID_RESPONSE',
      message: 'El servidor devolvió una respuesta inválida.',
    );
  }

  ApiException _toApiException(int statusCode, Map<String, dynamic> response) {
    final error = response['error'];
    if (error is Map) {
      final code = error['code'];
      final message = error['message'];
      if (code is String && message is String) {
        return ApiException(
          statusCode: statusCode,
          code: code,
          message: message,
        );
      }
    }

    return ApiException(
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
      message: _fallbackMessage(statusCode),
    );
  }

  String _fallbackMessage(int statusCode) => switch (statusCode) {
    401 => 'La sesión no es válida o ha expirado.',
    403 => 'No tienes permisos para realizar esta acción.',
    404 => 'No se encontró el recurso solicitado.',
    _ => 'No se pudo completar la solicitud.',
  };
}
