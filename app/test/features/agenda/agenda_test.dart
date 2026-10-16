import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/agenda/data/agenda_repository.dart';
import 'package:inkslot_app/features/agenda/domain/availability.dart';
import 'package:inkslot_app/features/agenda/domain/calendar_status.dart';
import 'package:inkslot_app/features/agenda/presentation/admin_agenda_page.dart';
import 'package:inkslot_app/features/agenda/presentation/agenda_controller.dart';

void main() {
  group('AgendaRepository', () {
    test('uses the calendar, availability and block endpoints', () async {
      final api = RecordingRestApiClient()
        ..getResults['/admin/calendar/status'] = {
          'status': 'needs_reconnect',
          'calendarName': 'Citas',
        }
        ..getResults['/admin/availability'] = _availabilityJson()
        ..getLists['/admin/blocks'] = [
          {
            'id': 'b1',
            'startAt': '2026-12-21T05:00:00.000Z',
            'endAt': '2026-12-29T05:00:00.000Z',
            'reason': null,
          },
        ]
        ..postResults['/admin/blocks'] = {
          'id': 'b2',
          'startAt': '2026-12-21T05:00:00.000Z',
          'endAt': '2026-12-22T05:00:00.000Z',
          'reason': 'Feriado',
        }
        ..postResults['/admin/calendar/reconnect'] = {
          'authorizationUrl': 'https://accounts.google.com/o/oauth2/auth',
          'expiresAt': '2026-10-16T12:00:00.000Z',
        };
      final repository = AgendaRepository(api);

      final status = await repository.calendarStatus();
      expect(status.state, CalendarConnectionState.needsReconnect);
      expect((await repository.availability())!.weeklyWindows, hasLength(1));
      expect((await repository.blocks()).single.reason, isNull);

      await repository.createBlock(
        startAt: DateTime.utc(2026, 12, 21, 5),
        endAt: DateTime.utc(2026, 12, 22, 5),
        reason: 'Feriado',
      );
      expect(api.lastBody, {
        'startAt': '2026-12-21T05:00:00.000Z',
        'endAt': '2026-12-22T05:00:00.000Z',
        'reason': 'Feriado',
      });

      final auth = await repository.reconnectCalendar();
      expect(auth.url, startsWith('https://accounts.google.com'));

      await repository.deleteBlock('b 1');
      expect(api.deleted, ['/admin/blocks/b%201']);

      await repository.disconnectCalendar();
      expect(api.posted, contains('/admin/calendar/disconnect'));
    });

    test('puts the whole availability document', () async {
      final api = RecordingRestApiClient()..putResult = _availabilityJson();
      final repository = AgendaRepository(api);
      await repository.updateAvailability(
        AdminAvailability.fromJson(_availabilityJson()),
      );
      expect(api.putPath, '/admin/availability');
      expect(api.lastBody!['slotStepMinutes'], 30);
      expect(api.lastBody!['weeklyWindows'], [
        {'weekday': 2, 'startLocal': '10:00', 'endLocal': '20:00'},
      ]);
    });

    test('treats an unconfigured availability as null', () async {
      final api = RecordingRestApiClient()
        ..getError = const ApiException(
          statusCode: 404,
          code: 'AVAILABILITY_NOT_CONFIGURED',
          message: 'No configurada',
        );
      expect(await AgendaRepository(api).availability(), isNull);
    });
  });

  group('AgendaController', () {
    test(
      'loads everything and toggles a day open with default hours',
      () async {
        final repository = FakeAgendaRepository();
        final controller = AgendaController(repository);
        await controller.load();

        expect(controller.status, AgendaLoadStatus.loaded);
        await controller.setDayOpen(1, true);
        final monday = controller.availability!.windowsFor(1).single;
        expect(monday.startLocal, '10:00');
        expect(monday.endLocal, '20:00');

        await controller.setDayOpen(2, false);
        expect(controller.availability!.windowsFor(2), isEmpty);
        await controller.setDayOpen(2, true);
        expect(
          controller.availability!.windowsFor(2).single.startLocal,
          '09:00',
        );
      },
    );

    test('keeps the previous week and reports save errors', () async {
      final repository = FakeAgendaRepository()..failUpdate = true;
      final controller = AgendaController(repository);
      await controller.load();
      final ok = await controller.setDayOpen(1, true);
      expect(ok, isFalse);
      expect(controller.availability!.windowsFor(1), isEmpty);
      expect(controller.actionError, 'Falló');
    });

    test('adds and removes blocks', () async {
      final controller = AgendaController(FakeAgendaRepository());
      await controller.load();
      await controller.addBlock(
        startAt: DateTime(2026, 12, 21),
        endAt: DateTime(2026, 12, 22),
        reason: 'Feriado',
      );
      expect(controller.blocks.map((b) => b.id), contains('new'));
      await controller.removeBlock('new');
      expect(controller.blocks, isEmpty);
    });

    test('surfaces load errors', () async {
      final controller = AgendaController(
        FakeAgendaRepository()..failLoad = true,
      );
      await controller.load();
      expect(controller.status, AgendaLoadStatus.error);
      expect(controller.errorMessage, 'Falló');
    });
  });

  group('AdminAgendaPage', () {
    Future<AgendaController> pump(
      WidgetTester tester,
      FakeAgendaRepository repository,
    ) async {
      final controller = AgendaController(repository);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(780, 3000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInkSlotTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 1500),
              disableAnimations: true,
            ),
            child: Scaffold(body: AdminAgendaPage(controller: controller)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('renders the connected calendar, week and rules', (
      tester,
    ) async {
      await pump(tester, FakeAgendaRepository());
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('CONECTADO'), findsOneWidget);
      expect(find.text('«Citas estudio»'), findsOneWidget);
      expect(find.text('Desconectar'), findsOneWidget);
      expect(find.text('09:00 - 18:00'), findsOneWidget);
      expect(find.text('Cerrado'), findsNWidgets(6));
      expect(find.text('America/Guayaquil'), findsOneWidget);
      expect(
        find.text('Sin bloqueos. Agrega vacaciones, feriados o descansos.'),
        findsOneWidget,
      );
    });

    testWidgets('offers reconnect when the permission expired', (tester) async {
      final repository = FakeAgendaRepository()
        ..calendar = CalendarConnectionState.needsReconnect;
      await pump(tester, repository);
      expect(find.text('RECONECTAR'), findsOneWidget);
      expect(find.text('Reconectar Google Calendar'), findsOneWidget);

      await tester.tap(find.text('Reconectar Google Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar enlace'), findsOneWidget);
      expect(find.text('https://accounts.google.com/auth'), findsOneWidget);
    });

    testWidgets('toggling a day saves the new week', (tester) async {
      final repository = FakeAgendaRepository();
      await pump(tester, repository);
      await tester.tap(find.bySemanticsLabel('Lun cerrado'));
      await tester.pumpAndSettle();
      expect(repository.saved!.windowsFor(1), hasLength(1));
      expect(find.text('Jornada actualizada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('creates a block from the sheet', (tester) async {
      final repository = FakeAgendaRepository();
      await pump(tester, repository);
      await tester.tap(find.text('+ Agregar'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo bloqueo'), findsOneWidget);

      await tester.tap(find.text('Feriado'));
      await tester.tap(find.text('Bloquear fechas'));
      await tester.pumpAndSettle();
      expect(repository.blockCreated, isTrue);
      expect(find.text('Feriado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('shows a retry state when loading fails', (tester) async {
      await pump(tester, FakeAgendaRepository()..failLoad = true);
      expect(find.text('No pudimos cargar tu agenda.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  test('formats block ranges like the prototype', () {
    expect(
      formatBlockRange(DateTime(2026, 10, 31), DateTime(2026, 11, 1)),
      'sáb 31 oct',
    );
    expect(
      formatBlockRange(DateTime(2026, 12, 21), DateTime(2026, 12, 29)),
      '21 – 28 dic',
    );
    expect(
      formatBlockRange(DateTime(2026, 12, 31), DateTime(2027, 1, 3)),
      '31 dic – 2 ene',
    );
  });
}

Map<String, dynamic> _availabilityJson() => {
  'timezone': 'America/Guayaquil',
  'slotStepMinutes': 30,
  'bufferMinutes': 15,
  'minimumNoticeHours': 24,
  'horizonDays': 60,
  'weeklyWindows': [
    {'weekday': 2, 'startLocal': '10:00', 'endLocal': '20:00'},
  ],
};

class FakeAgendaRepository extends AgendaRepository {
  FakeAgendaRepository() : super(RecordingRestApiClient());

  CalendarConnectionState calendar = CalendarConnectionState.connected;
  bool failLoad = false;
  bool failUpdate = false;
  bool blockCreated = false;
  AdminAvailability? saved;
  AdminAvailability current = const AdminAvailability(
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 24,
    horizonDays: 60,
    weeklyWindows: [
      WeeklyWindow(weekday: 2, startLocal: '09:00', endLocal: '18:00'),
    ],
  );
  List<AvailabilityBlock> blockList = [];

  @override
  Future<CalendarStatus> calendarStatus() async {
    if (failLoad) throw const ApiException(code: 'X', message: 'Falló');
    return CalendarStatus(state: calendar, calendarName: 'Citas estudio');
  }

  @override
  Future<CalendarAuthorization> reconnectCalendar() async =>
      CalendarAuthorization(
        url: 'https://accounts.google.com/auth',
        expiresAt: DateTime.utc(2026, 10, 16, 12),
      );

  @override
  Future<AdminAvailability?> availability() async => current;

  @override
  Future<AdminAvailability> updateAvailability(
    AdminAvailability availability,
  ) async {
    if (failUpdate) throw const ApiException(code: 'X', message: 'Falló');
    saved = availability;
    current = availability;
    return availability;
  }

  @override
  Future<List<AvailabilityBlock>> blocks() async => blockList;

  @override
  Future<AvailabilityBlock> createBlock({
    required DateTime startAt,
    required DateTime endAt,
    String? reason,
  }) async {
    blockCreated = true;
    final block = AvailabilityBlock(
      id: 'new',
      startAt: startAt,
      endAt: endAt,
      reason: reason,
    );
    blockList = [...blockList, block];
    return block;
  }

  @override
  Future<void> deleteBlock(String id) async {
    blockList = blockList.where((b) => b.id != id).toList();
  }
}

class RecordingRestApiClient implements RestApiClient {
  final Map<String, Map<String, dynamic>> getResults = {};
  final Map<String, List<dynamic>> getLists = {};
  final Map<String, Map<String, dynamic>> postResults = {};
  final List<String> posted = [];
  final List<String> deleted = [];
  Map<String, dynamic>? putResult;
  String? putPath;
  Map<String, dynamic>? lastBody;
  ApiException? getError;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (getError != null) throw getError!;
    return getResults[path] ?? {};
  }

  @override
  Future<List<dynamic>> getJsonList(String path) async => getLists[path] ?? [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    posted.add(path);
    lastBody = body;
    return postResults[path] ?? {};
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    putPath = path;
    lastBody = body;
    return putResult ?? {};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async => {};

  @override
  Future<void> deleteJson(String path) async => deleted.add(path);
}
