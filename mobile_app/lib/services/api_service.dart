import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/risk_assessment.dart';

/// Excepción tipada para errores de la API.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Servicio centralizado para todas las llamadas a la API Flask.
/// La URL base se obtiene exclusivamente de [ApiConfig.baseUrl].
class ApiService {
  static final http.Client _client = http.Client();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Obtiene la lista completa de evaluaciones de riesgo.
  static Future<List<RiskAssessment>> fetchAssessments() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/assessments'), headers: _headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
        return body
            .map((e) => RiskAssessment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const ApiException('Error al cargar evaluaciones');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  /// Crea una nueva evaluación. Espera respuesta 201 con el recurso creado.
  static Future<RiskAssessment> createAssessment(
      RiskAssessment assessment) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/assessments'),
            headers: _headers,
            body: jsonEncode(assessment.toJson()),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 201) {
        return RiskAssessment.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      final error = _extractError(response.body);
      throw ApiException(error ?? 'Error al crear evaluación (${response.statusCode})');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  /// Actualiza una evaluación existente. Espera respuesta 200 con el recurso actualizado.
  static Future<RiskAssessment> updateAssessment(
      RiskAssessment assessment) async {
    assert(assessment.id != null, 'updateAssessment requiere un id válido');
    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/assessments/${assessment.id}'),
            headers: _headers,
            body: jsonEncode(assessment.toJson()),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return RiskAssessment.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      final error = _extractError(response.body);
      throw ApiException(
          error ?? 'Error al actualizar evaluación (${response.statusCode})');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  /// Elimina una evaluación por id. Espera respuesta 200.
  static Future<void> deleteAssessment(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse('${ApiConfig.baseUrl}/assessments/$id'), headers: _headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200) {
        final error = _extractError(response.body);
        throw ApiException(
            error ?? 'Error al eliminar evaluación (${response.statusCode})');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  /// Extrae el campo "error" del cuerpo JSON de respuesta si existe.
  static String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['error'] as String?;
    } catch (_) {
      return null;
    }
  }
}
