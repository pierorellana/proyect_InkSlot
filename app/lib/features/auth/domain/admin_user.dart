import '../../../core/network/api_exception.dart';

class AdminUser {
  const AdminUser({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final role = json['role'];

    if (id is! String || name is! String || role is! String) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'El servidor devolvió un usuario inválido.',
      );
    }

    return AdminUser(id: id, name: name, role: role);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminUser &&
        other.id == id &&
        other.name == name &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, name, role);
}
