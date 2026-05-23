// lib/models/assessment_pack.dart — TDS Sentinel
// Modelos para Assessment Packs y Controls.

class AssessmentControl {
  final String id;
  final String question;
  final int weight;

  const AssessmentControl({
    required this.id,
    required this.question,
    required this.weight,
  });

  factory AssessmentControl.fromJson(Map<String, dynamic> json) {
    return AssessmentControl(
      id:       json['id'] as String,
      question: json['question'] as String,
      weight:   (json['weight'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':       id,
    'question': question,
    'weight':   weight,
  };
}

class AssessmentPack {
  final String id;
  final String name;
  final String description;
  final String version;
  final List<AssessmentControl> controls;

  const AssessmentPack({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.controls,
  });

  factory AssessmentPack.fromJson(Map<String, dynamic> json) {
    final rawControls = json['controls'] as List<dynamic>? ?? [];
    return AssessmentPack(
      id:          json['id'] as String,
      name:        json['name'] as String,
      description: json['description'] as String,
      version:     json['version'] as String,
      controls:    rawControls
          .map((c) => AssessmentControl.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
