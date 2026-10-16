import 'public_confirmation.dart';

class PublicAppointment {
  const PublicAppointment({
    required this.status,
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String status;
  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;

  factory PublicAppointment.fromJson(Map<String, dynamic> json) {
    final confirmation = PublicConfirmation.fromJson(json);
    return PublicAppointment(
      status: confirmation.status,
      syncStatus: confirmation.syncStatus,
      startAt: confirmation.startAt,
      endAt: confirmation.endAt,
      timezone: confirmation.timezone,
    );
  }
}
