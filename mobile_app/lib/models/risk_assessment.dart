/// Modelo que representa una evaluación de riesgo de ciberseguridad.
/// Mapea directamente la estructura JSON devuelta por la API Flask.
class RiskAssessment {
  final int? id;
  final String companyName;
  final String assetName;
  final String riskLevel;
  final String recommendation;
  final String? createdAt;

  const RiskAssessment({
    this.id,
    required this.companyName,
    required this.assetName,
    required this.riskLevel,
    required this.recommendation,
    this.createdAt,
  });

  /// Valores permitidos para riskLevel según la API y la base de datos.
  static const List<String> validRiskLevels = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      id: json['id'] as int?,
      companyName: json['company_name'] as String? ?? '',
      assetName: json['asset_name'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'Low',
      recommendation: json['recommendation'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'asset_name': assetName,
      'risk_level': riskLevel,
      'recommendation': recommendation,
    };
  }

  /// Crea una copia del modelo con los campos indicados reemplazados.
  RiskAssessment copyWith({
    int? id,
    String? companyName,
    String? assetName,
    String? riskLevel,
    String? recommendation,
    String? createdAt,
  }) {
    return RiskAssessment(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      assetName: assetName ?? this.assetName,
      riskLevel: riskLevel ?? this.riskLevel,
      recommendation: recommendation ?? this.recommendation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
