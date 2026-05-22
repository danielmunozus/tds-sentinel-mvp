// lib/models/client.dart — TDS Sentinel
class Client {
  final int id;
  final String name;
  final String? contactName;
  final String? email;
  final String? industry;
  final String createdAt;
  final String? updatedAt;

  const Client({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.industry,
    required this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id:          (json['id'] as num).toInt(),
      name:        json['name'] as String,
      contactName: json['contact_name'] as String?,
      email:       json['email'] as String?,
      industry:    json['industry'] as String?,
      createdAt:   json['created_at'] as String,
      updatedAt:   json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'contact_name': contactName,
    'email':        email,
    'industry':     industry,
    'created_at':   createdAt,
    'updated_at':   updatedAt,
  };
}
