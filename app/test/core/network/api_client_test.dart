import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:inkslot_app/core/config/app_config.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';

void main() {
  test('uses the configured local API base URL by default', () {
    expect(AppConfig.apiBaseUri, Uri.parse('http://localhost:3000/v1'));
  });

  test('joins API paths and decodes JSON responses', () async {
    final client = RecordingHttpClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, Uri.parse('https://api.example.test/v1/auth/me'));
      expect(request.headers['accept'], 'application/json');
      return http.Response(
        '{"user":{"id":"artist-1"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('https://api.example.test/v1/'),
    );

    expect(await api.getJson('/auth/me'), {
      'user': {'id': 'artist-1'},
    });
  });

  test('keeps query parameters separate when joining API paths', () async {
    final client = RecordingHttpClient((request) async {
      expect(
        request.url,
        Uri.parse(
          'https://api.example.test/v1/public/reservations/demo-token/availability'
          '?from=2026-10-16&to=2026-10-31',
        ),
      );
      return http.Response('{"days":[],"timezone":"UTC"}', 200);
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('https://api.example.test/v1'),
    );

    await api.getJson(
      '/public/reservations/demo-token/availability'
      '?from=2026-10-16&to=2026-10-31',
    );
  });

  test('posts JSON and accepts an empty successful response', () async {
    final client = RecordingHttpClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('http://localhost:3000/v1/auth/login'));
      expect(request.headers['content-type'], 'application/json');
      expect((request as http.Request).body, '{"email":"a@b.test"}');
      return http.Response('', 204);
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('http://localhost:3000/v1'),
    );

    expect(
      await api.postJson('auth/login', body: {'email': 'a@b.test'}),
      isEmpty,
    );
  });

  test('merges optional headers into JSON requests', () async {
    final client = RecordingHttpClient((request) async {
      expect(request.headers['accept'], 'application/json');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['idempotency-key'], 'key-in-memory');
      return http.Response('{"status":"ok"}', 200);
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('http://localhost:3000/v1'),
    );

    expect(
      await api.postJson(
        '/public/reservations/token/confirm',
        body: <String, dynamic>{'startAt': '2026-10-20T15:00:00.000Z'},
        headers: <String, String>{'Idempotency-Key': 'key-in-memory'},
      ),
      <String, dynamic>{'status': 'ok'},
    );
  });

  test(
    'maps the safe API error envelope without exposing raw failures',
    () async {
      final api = HttpApiClient(
        client: RecordingHttpClient((_) async {
          return http.Response(
            '{"error":{"code":"AUTH_INVALID","message":"Credenciales inválidas"}}',
            401,
          );
        }),
      );

      await expectLater(
        api.getJson('/auth/me'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 401)
              .having((error) => error.code, 'code', 'AUTH_INVALID')
              .having(
                (error) => error.message,
                'message',
                'Credenciales inválidas',
              )
              .having((error) => error.isUnauthorized, 'unauthorized', isTrue),
        ),
      );
    },
  );

  test('converts transport failures to a safe network error', () async {
    final api = HttpApiClient(
      client: RecordingHttpClient((_) async {
        throw StateError('private transport details');
      }),
    );

    await expectLater(
      api.getJson('/auth/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'NETWORK_ERROR')
            .having(
              (error) => error.message,
              'message',
              'No se pudo conectar con el servidor.',
            )
            .having(
              (error) => error.toString().contains('private transport details'),
              'does not expose transport details',
              isFalse,
            ),
      ),
    );
  });

  test('supports lists, PUT, PATCH and DELETE', () async {
    final methods = <String>[];
    final client = RecordingHttpClient((request) async {
      methods.add(request.method);
      if (request.method == 'DELETE') return http.Response('', 204);
      if (request.method == 'GET') return http.Response('[{"id":"b1"}]', 200);
      return http.Response('{"ok":true}', 200);
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('http://localhost:3000/v1'),
    );

    expect(await api.getJsonList('/admin/blocks'), [
      {'id': 'b1'},
    ]);
    expect(await api.putJson('/admin/availability', body: {'a': 1}), {
      'ok': true,
    });
    expect(await api.patchJson('/admin/appointments/1/reschedule'), {
      'ok': true,
    });
    await api.deleteJson('/admin/blocks/b1');
    expect(methods, ['GET', 'PUT', 'PATCH', 'DELETE']);
    await expectLater(
      api.getJson('/admin/blocks'),
      throwsA(isA<ApiException>()),
    );
  });
}

class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
