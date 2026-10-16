import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_primary_button.dart';
import 'package:inkslot_app/features/sync_issues/data/sync_issues_repository.dart';
import 'package:inkslot_app/features/sync_issues/domain/sync_issue.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_controller.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_page.dart';

void main() {
  testWidgets('renders title and reloads the selected filter', (tester) async {
    final repository = FakeSyncIssuesRepository(
      listResponses: [
        SyncIssueList(items: [_issue('open-1')]),
        SyncIssueList(
          items: [_issue('resolved-1', status: SyncIssueStatus.resolved)],
        ),
      ],
    );
    final controller = SyncIssuesController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(SyncIssuesPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Incidencias'), findsOneWidget);
    expect(find.text('Abiertas'), findsOneWidget);
    expect(find.text('Resueltas'), findsOneWidget);
    expect(find.text('No fue posible sincronizar el evento.'), findsOneWidget);

    await tester.tap(find.text('Resueltas'));
    await tester.pumpAndSettle();

    expect(controller.filter, SyncIssueStatus.resolved);
    expect(repository.filters, [
      SyncIssueStatus.open,
      SyncIssueStatus.resolved,
    ]);
    expect(find.text('Incidencia resuelta.'), findsOneWidget);
  });

  testWidgets('shows the empty state for a filter without issues', (
    tester,
  ) async {
    final controller = SyncIssuesController(
      FakeSyncIssuesRepository(listResponses: [const SyncIssueList(items: [])]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(SyncIssuesPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No hay incidencias en este estado.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('shows an error and retries the initial load', (tester) async {
    final repository = FakeSyncIssuesRepository(
      listResponses: [
        const ApiException(
          statusCode: 500,
          code: 'SERVER_ERROR',
          message: 'No se pudieron cargar las incidencias.',
        ),
        const SyncIssueList(items: []),
      ],
    );
    final controller = SyncIssuesController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(SyncIssuesPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar las incidencias.'), findsOneWidget);
    final retryButton = find.widgetWithText(InkSlotPrimaryButton, 'Reintentar');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.filters, [SyncIssueStatus.open, SyncIssueStatus.open]);
    expect(find.text('No hay incidencias en este estado.'), findsOneWidget);
  });

  testWidgets('shows retry only on open issue cards', (tester) async {
    final repository = FakeSyncIssuesRepository(
      listResponses: [
        SyncIssueList(items: [_issue('open-1')]),
        const SyncIssueList(items: []),
      ],
    );
    final controller = SyncIssuesController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(SyncIssuesPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No fue posible sincronizar el evento.'), findsOneWidget);
    final retryButton = find.widgetWithText(InkSlotPrimaryButton, 'Reintentar');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.retriedIds, ['open-1']);

    final resolvedController = SyncIssuesController(
      FakeSyncIssuesRepository(
        listResponses: [
          SyncIssueList(
            items: [_issue('resolved-1', status: SyncIssueStatus.resolved)],
          ),
        ],
      ),
    );
    await resolvedController.setFilter(SyncIssueStatus.resolved);
    addTearDown(resolvedController.dispose);

    await tester.pumpWidget(
      _host(SyncIssuesPage(controller: resolvedController)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incidencia resuelta.'), findsOneWidget);
    expect(
      find.widgetWithText(InkSlotPrimaryButton, 'Reintentar'),
      findsNothing,
    );
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: buildInkSlotTheme(),
  home: Scaffold(body: child),
);

class FakeSyncIssuesRepository extends SyncIssuesRepository {
  FakeSyncIssuesRepository({required this.listResponses})
    : super(FakeApiClient());

  final List<Object> listResponses;
  final List<SyncIssueStatus> filters = <SyncIssueStatus>[];
  final List<String> retriedIds = <String>[];
  var _listIndex = 0;

  @override
  Future<SyncIssueList> list({
    SyncIssueStatus status = SyncIssueStatus.open,
  }) async {
    filters.add(status);
    final response = _listIndex < listResponses.length
        ? listResponses[_listIndex++]
        : const SyncIssueList(items: []);
    if (response is SyncIssueList) return response;
    throw response;
  }

  @override
  Future<void> retry(String id) async {
    retriedIds.add(id);
  }
}

class FakeApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => <String, dynamic>{};
}

SyncIssue _issue(String id, {SyncIssueStatus status = SyncIssueStatus.open}) =>
    SyncIssue(
      id: id,
      appointmentId: 'appointment-$id',
      operation: 'appointment.calendar.update',
      code: 'CALENDAR_UNAVAILABLE',
      message: status == SyncIssueStatus.open
          ? 'No fue posible sincronizar el evento.'
          : 'Incidencia resuelta.',
      status: status,
      lastAttemptAt: null,
      createdAt: DateTime.utc(2026, 10, 16),
    );
