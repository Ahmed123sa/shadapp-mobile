/// Data shape for a client record, as returned by `/clients` and
/// `/clients/:id`. Centralizes the field parsing that used to be repeated
/// (slightly differently each time) in every screen that read a client map
/// directly — see client_detail_page.dart, sa_clients_page.dart,
/// create_client_page.dart for the original inline versions.
class Client {
  final int id;
  final String companyName;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? country;
  final String? industry;
  final String? address;
  final String? dateOfBirth;
  final String status;
  final String? clientType;
  final String? avatarUrl;
  final String? createdAt;

  const Client({
    required this.id,
    required this.companyName,
    this.contactPerson,
    this.email,
    this.phone,
    this.country,
    this.industry,
    this.address,
    this.dateOfBirth,
    this.status = 'inactive',
    this.clientType,
    this.avatarUrl,
    this.createdAt,
  });

  /// Every field but `id`/`company_name` is defensively nullable-or-defaulted
  /// here — the same protection that used to be scattered as `?? ''` at each
  /// call site now lives in one place. Uses `_str`/`_int` instead of a bare
  /// `as String?` cast: a wrong-typed value (e.g. a number where a string was
  /// expected — real, seen-in-the-wild bad data) would make `as String?`
  /// throw instead of returning null, taking down the whole list parse over
  /// one bad record.
  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: _int(json['id']) ?? 0,
        companyName: _str(json['company_name']) ?? '',
        contactPerson: _str(json['contact_person']),
        email: _str(json['email']),
        phone: _str(json['phone']),
        country: _str(json['country']),
        industry: _str(json['industry']),
        address: _str(json['address']),
        dateOfBirth: _str(json['date_of_birth']),
        status: _str(json['status']) ?? 'inactive',
        clientType: _str(json['client_type']),
        avatarUrl: _str(json['avatar_url']),
        createdAt: _str(json['created_at']),
      );
}

String? _str(dynamic value) => value is String ? value : null;

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
