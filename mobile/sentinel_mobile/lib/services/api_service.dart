// lib/services/api_service.dart — TDS Sentinel
// Capa de servicio HTTP. Toda comunicación con Flask pasa por aquí.
// Los screens nunca construyen URLs ni tocan http directamente.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/assessment_pack.dart';
import '../models/client.dart';
import '../models/risk_assessment.dart';

// Excepción tipada para errores de API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  // ── Helpers internos ───────────────────────────────────────────────────────

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  /// Procesa la respuesta HTTP. Lanza ApiException si el status >= 400.
  /// Nunca expone el stack trace interno al usuario.
  dynamic _processResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return null;
      return json.decode(body);
    }
    // Intentar extraer mensaje de error del JSON
    String errorMsg = 'Error del servidor (${response.statusCode})';
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('error')) {
        errorMsg = decoded['error'] as String;
      }
    } catch (_) {}
    throw ApiException(errorMsg, statusCode: response.statusCode);
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.health), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ── Clients ────────────────────────────────────────────────────────────────

  Future<List<Client>> fetchClients() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.clients), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as List<dynamic>;
      return data
          .map((c) => Client.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo cargar la lista de clientes.');
    }
  }

  Future<Client> createClient({
    required String name,
    String? contactName,
    String? email,
    String? industry,
  }) async {
    if (name.trim().isEmpty) throw const ApiException('El nombre del cliente es requerido.');
    try {
      final body = json.encode({
        'name':         name.trim(),
        if (contactName != null && contactName.trim().isNotEmpty)
          'contact_name': contactName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (industry != null && industry.trim().isNotEmpty) 'industry': industry.trim(),
      });
      final response = await _client
          .post(Uri.parse(ApiConfig.clients), headers: _headers, body: body)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return Client.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo crear el cliente.');
    }
  }

  Future<Client> updateClient(int id, {String? name, String? contactName, String? email, String? industry}) async {
    try {
      final payload = <String, String>{};
      if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
      if (contactName != null) payload['contact_name'] = contactName.trim();
      if (email != null) payload['email'] = email.trim();
      if (industry != null) payload['industry'] = industry.trim();
      if (payload.isEmpty) throw const ApiException('No hay campos para actualizar.');
      final response = await _client
          .put(Uri.parse(ApiConfig.clientById(id)), headers: _headers, body: json.encode(payload))
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return Client.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo actualizar el cliente.');
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse(ApiConfig.clientById(id)), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo eliminar el cliente.');
    }
  }

  // ── Packs ──────────────────────────────────────────────────────────────────

  Future<List<AssessmentPack>> fetchPacks() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.packs), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as List<dynamic>;
      return data
          .map((p) => AssessmentPack.fromJson(p as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo conectar con el servidor. Verifica que la API esté corriendo.');
    }
  }

  // ── Assessments ────────────────────────────────────────────────────────────

  Future<List<RiskAssessment>> fetchAssessments() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.assessments), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as List<dynamic>;
      return data
          .map((a) => RiskAssessment.fromJson(a as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo cargar el historial de evaluaciones.');
    }
  }

  Future<RiskAssessment> fetchAssessmentById(int id) async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.assessmentById(id)), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return RiskAssessment.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo cargar la evaluación.');
    }
  }

  Future<RiskAssessment> createAssessment({
    required int clientId,
    required String responsibleName,
    required String packId,
    required Map<String, String> answers,
  }) async {
    if (responsibleName.trim().isEmpty) throw const ApiException('El nombre del responsable es requerido.');
    if (answers.isEmpty) throw const ApiException('Debe responder al menos un control.');

    try {
      final body = json.encode({
        'client_id':        clientId,
        'responsible_name': responsibleName.trim(),
        'pack_id':          packId,
        'answers':          answers,
      });
      final response = await _client
          .post(Uri.parse(ApiConfig.assessments), headers: _headers, body: body)
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return RiskAssessment.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo crear la evaluación. Verifica tu conexión.');
    }
  }

  Future<RiskAssessment> updateAssessment(
    int id, {
    String? companyName,
    String? responsibleName,
  }) async {
    try {
      final payload = <String, String>{};
      if (companyName != null && companyName.trim().isNotEmpty) {
        payload['company_name'] = companyName.trim();
      }
      if (responsibleName != null && responsibleName.trim().isNotEmpty) {
        payload['responsible_name'] = responsibleName.trim();
      }
      if (payload.isEmpty) throw const ApiException('No hay campos para actualizar.');

      final response = await _client
          .put(Uri.parse(ApiConfig.assessmentById(id)),
               headers: _headers, body: json.encode(payload))
          .timeout(ApiConfig.requestTimeout);
      final data = _processResponse(response) as Map<String, dynamic>;
      return RiskAssessment.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo actualizar la evaluación.');
    }
  }

  Future<void> deleteAssessment(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse(ApiConfig.assessmentById(id)), headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('No se pudo eliminar la evaluación.');
    }
  }
}
