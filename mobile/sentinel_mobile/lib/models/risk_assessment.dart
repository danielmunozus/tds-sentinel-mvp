// lib/models/risk_assessment.dart — TDS Sentinel
// Modelo de evaluación de riesgo persistida.

class Recommendation {
  final String controlId;
  final String question;
  final String answer;
  final String priority;
  final int weight;
  final String recommendation;

  const Recommendation({
    required this.controlId,
    required this.question,
    required this.answer,
    required this.priority,
    required this.weight,
    required this.recommendation,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      controlId:      json['control_id'] as String,
      question:       json['question'] as String,
      answer:         json['answer'] as String,
      priority:       json['priority'] as String,
      weight:         (json['weight'] as num).toInt(),
      recommendation: json['recommendation'] as String,
    );
  }
}

class RiskAssessment {
  final int id;
  final String companyName;
  final String responsibleName;
  final String packId;
  final Map<String, String> answers;
  final double score;
  final String riskLevel;
  final List<Recommendation> recommendations;
  final String assessmentHash;
  final String createdAt;
  final String? updatedAt;

  const RiskAssessment({
    required this.id,
    required this.companyName,
    required this.responsibleName,
    required this.packId,
    required this.answers,
    required this.score,
    required this.riskLevel,
    required this.recommendations,
    required this.assessmentHash,
    required this.createdAt,
    this.updatedAt,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    // answers_json puede venir como Map ya deserializado
    final rawAnswers = json['answers_json'];
    final Map<String, String> answers = rawAnswers is Map
        ? rawAnswers.map((k, v) => MapEntry(k.toString(), v.toString()))
        : {};

    // recommendations_json puede venir como List ya deserializada
    final rawRecs = json['recommendations_json'];
    final List<Recommendation> recs = rawRecs is List
        ? rawRecs
            .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
            .toList()
        : [];

    return RiskAssessment(
      id:               (json['id'] as num).toInt(),
      companyName:      json['company_name'] as String,
      responsibleName:  json['responsible_name'] as String,
      packId:           json['pack_id'] as String,
      answers:          answers,
      score:            (json['score'] as num).toDouble(),
      riskLevel:        json['risk_level'] as String,
      recommendations:  recs,
      assessmentHash:   json['assessment_hash'] as String,
      createdAt:        json['created_at'] as String,
      updatedAt:        json['updated_at'] as String?,
    );
  }

  // Score visual entero para mostrar en UI (0-100)
  int get scoreInt => score.round();
}
