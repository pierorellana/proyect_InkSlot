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

/// Verbos adicionales del API de administración (PUT, PATCH, DELETE y listas).
abstract class RestApiClient implements ApiClient {
  Future<List<dynamic>> getJsonList(String path);

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  });

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  });

  Future<void> deleteJson(String path);
}

class HttpApiClient implements RestApiClient {
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

  @override
  Future<List<dynamic>> getJsonList(String path) async {
    final decoded = await _send(method: 'GET', path: path);
    if (decoded is List) return decoded;
    throw const ApiException(
      code: 'INVALID_RESPONSE',
      message: 'El servidor devolvió una respuesta inválida.',
    );
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) => _request(method: 'PUT', path: path, body: body);

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) => _request(method: 'PATCH', path: path, body: body);

  @override
  Future<void> deleteJson(String path) async {
    await _send(method: 'DELETE', path: path);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final decoded = await _send(
      method: method,
      path: path,
      body: body,
      headers: headers,
    );
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(
      code: 'INVALID_RESPONSE',
      message: 'El servidor devolvió una respuesta inválida.',
    );
  }

  Future<Object> _send({
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
      throw _toApiException(
        response.statusCode,
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );
    }

    return decoded;
  }

  Uri _buildUri(String path) {
    final basePath = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final requestPath = path.replaceFirst(RegExp(r'^/+'), '');

    return _baseUri.replace(path: '$basePath/$requestPath');
  }

  Object _decode(String body) {
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
    if (decoded is List) return decoded;

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
