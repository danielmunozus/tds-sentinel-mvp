// lib/models/client.dart — TDS Sentinel v3
class Client {
  final int id;
  final String companyName;
  final String contactName;
  final String email;
  final String phone;
  final String bsArea;
  final String clientStatus;
  final String createdAt;
  final String? updatedAt;

  const Client({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.bsArea,
    required this.clientStatus,
    required this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id:           (json['id'] as num).toInt(),
      companyName:  json['company_name'] as String,
      contactName:  json['contact_name'] as String? ?? '',
      email:        json['email'] as String,
      phone:        json['phone'] as String? ?? '',
      bsArea:       json['bs_area'] as String? ?? '',
      clientStatus: json['client_status'] as String? ?? 'enabled',
      createdAt:    json['created_at'] as String,
      updatedAt:    json['updated_at'] as String?,
    );
  }

  bool get isEnabled => clientStatus == 'enabled';
}
