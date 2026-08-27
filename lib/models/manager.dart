/// Data shape for an account manager, as returned by `/account-managers` and
/// `/account-managers/:id`. See docs/state-layer-migration-plan.md — same
/// defensive-parsing rationale as lib/models/client.dart.
class Manager {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? dateOfBirth;
  final int managedClientsCount;

  const Manager({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.managedClientsCount = 0,
  });

  factory Manager.fromJson(Map<String, dynamic> json) => Manager(
        id: _int(json['id']) ?? 0,
        name: _str(json['name']) ?? '',
        email: _str(json['email']),
        phone: _str(json['phone']),
        avatarUrl: _str(json['avatar_url']),
        dateOfBirth: _str(json['date_of_birth']),
        managedClientsCount: _int(json['managed_clients_count']) ?? 0,
      );
}

String? _str(dynamic value) => value is String ? value : null;

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
