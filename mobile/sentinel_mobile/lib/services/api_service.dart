// lib/services/api_service.dart — TDS Sentinel
// Capa de servicio HTTP. Toda comunicación con Flask pasa por aquí.
// v3.1: incluye Bearer token en todas las requests autenticadas.

import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_state.dart';
import '../models/assessment_pack.dart';
import '../models/client.dart';
import '../models/risk_assessment.dart';

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

  http.Client _http = http.Client();

  /// Permite inyectar un [http.Client] alternativo en tests.
  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set httpClientForTesting(http.Client client) => _http = client;

  /// Headers base (sin auth) — solo para endpoints públicos.
  Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  /// Headers autenticados — incluye Bearer token de la sesión activa.
  Map<String, String> get _authHeaders {
    final token = AppState.instance.token;
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _process(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isEmpty ? null : json.decode(body);
    }
    String msg = 'Error del servidor (${response.statusCode})';
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('error')) msg = decoded['error'] as String;
    } catch (_) {}
    throw ApiException(msg, statusCode: response.statusCode);
  }

  // ── Health (público) ────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.health), headers: _publicHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ── Auth (público) ──────────────────────────────────────────────────────────

  /// Login: devuelve el Client y almacena el token en AppState.
  Future<Client> login(String email, String password) async {
    try {
      final r = await _http.post(Uri.parse(ApiConfig.login), headers: _publicHeaders,
          body: json.encode({'email': email.trim(), 'password': password}))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      final token  = data['token'] as String;
      final client = Client.fromJson(data['client'] as Map<String, dynamic>);
      // Almacenar sesión en AppState para que _authHeaders lo incluya automáticamente
      AppState.instance.login(client, token);
      return client;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo conectar con el servidor.');
    }
  }

  /// Logout: invalida el token en el servidor y limpia AppState.
  Future<void> logout() async {
    try {
      await _http.post(Uri.parse(ApiConfig.logout), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
    } catch (_) {
      // Si falla la petición, igual limpiamos la sesión local
    } finally {
      AppState.instance.logout();
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final r = await _http.post(Uri.parse(ApiConfig.forgotPassword), headers: _publicHeaders,
          body: json.encode({'email': email.trim()}))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return data['message'] as String? ?? 'Solicitud enviada.';
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo enviar la solicitud.');
    }
  }

  Future<String> sendContactRequest({
    required String companyName,
    required String contactName,
    required String email,
    String? phone,
    String? packInterest,
    String? message,
  }) async {
    try {
      final r = await _http.post(Uri.parse(ApiConfig.contact), headers: _publicHeaders,
          body: json.encode({
            'company_name':  companyName.trim(),
            'contact_name':  contactName.trim(),
            'email':         email.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
            if (packInterest != null && packInterest.trim().isNotEmpty)
              'pack_interest': packInterest.trim(),
            if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
          }))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return data['message'] as String? ?? 'Solicitud enviada.';
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo enviar la solicitud de contacto.');
    }
  }

  // ── Clients (autenticado) ───────────────────────────────────────────────────

  Future<List<Client>> fetchClients() async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.clients), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as List<dynamic>;
      return data.map((c) => Client.fromJson(c as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo cargar la lista de clientes.');
    }
  }

  Future<Client> createClient({
    required String companyName,
    required String email,
    required String password,
    String? contactName,
    String? phone,
    String? bsArea,
  }) async {
    if (companyName.trim().isEmpty) throw const ApiException('El nombre de empresa es requerido.');
    if (email.trim().isEmpty)       throw const ApiException('El email es requerido.');
    if (password.isEmpty)           throw const ApiException('La contraseña es requerida.');
    try {
      final r = await _http.post(Uri.parse(ApiConfig.clients), headers: _authHeaders,
          body: json.encode({
            'company_name': companyName.trim(),
            'email':        email.trim(),
            'password':     password,
            if (contactName != null && contactName.trim().isNotEmpty)
              'contact_name': contactName.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
            if (bsArea != null && bsArea.trim().isNotEmpty) 'bs_area': bsArea.trim(),
          }))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return Client.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo crear el cliente.');
    }
  }

  Future<Client> updateClient(int id, {
    String? companyName,
    String? contactName,
    String? email,
    String? phone,
    String? bsArea,
    String? clientStatus,
  }) async {
    try {
      final payload = <String, String>{};
      if (companyName != null && companyName.trim().isNotEmpty) {
        payload['company_name'] = companyName.trim();
      }
      if (contactName != null) payload['contact_name'] = contactName.trim();
      if (email != null && email.trim().isNotEmpty) payload['email'] = email.trim();
      if (phone != null) payload['phone'] = phone.trim();
      if (bsArea != null) payload['bs_area'] = bsArea.trim();
      if (clientStatus != null) payload['client_status'] = clientStatus;
      if (payload.isEmpty) throw const ApiException('No hay campos para actualizar.');
      final r = await _http.put(Uri.parse(ApiConfig.clientById(id)), headers: _authHeaders,
          body: json.encode(payload))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return Client.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo actualizar el cliente.');
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      final r = await _http.delete(Uri.parse(ApiConfig.clientById(id)), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      _process(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo eliminar el cliente.');
    }
  }

  // ── Packs (público) ─────────────────────────────────────────────────────────

  Future<List<AssessmentPack>> fetchPacks() async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.packs), headers: _publicHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as List<dynamic>;
      return data.map((p) => AssessmentPack.fromJson(p as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo conectar con el servidor. Verifica que la API esté corriendo.');
    }
  }

  // ── Assessments (autenticado) ───────────────────────────────────────────────

  Future<List<RiskAssessment>> fetchAssessments() async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.assessments), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as List<dynamic>;
      return data.map((a) => RiskAssessment.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo cargar el historial de evaluaciones.');
    }
  }

  Future<List<RiskAssessment>> fetchClientAssessments(int clientId) async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.clientAssessments(clientId)), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as List<dynamic>;
      return data.map((a) => RiskAssessment.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo cargar el historial de evaluaciones.');
    }
  }

  Future<RiskAssessment> fetchAssessmentById(int id) async {
    try {
      final r = await _http.get(Uri.parse(ApiConfig.assessmentById(id)), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return RiskAssessment.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo cargar la evaluación.');
    }
  }

  Future<RiskAssessment> createAssessment({
    required int clientId,
    required String packId,
    required Map<String, String> answers,
  }) async {
    if (answers.isEmpty) throw const ApiException('Debe responder al menos un control.');
    try {
      final r = await _http.post(Uri.parse(ApiConfig.assessments), headers: _authHeaders,
          body: json.encode({
            'client_id': clientId,
            'pack_id':   packId,
            'answers':   answers,
          }))
          .timeout(ApiConfig.requestTimeout);
      final data = _process(r) as Map<String, dynamic>;
      return RiskAssessment.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo crear la evaluación. Verifica tu conexión.');
    }
  }

  Future<void> deleteAssessment(int id) async {
    try {
      final r = await _http.delete(Uri.parse(ApiConfig.assessmentById(id)), headers: _authHeaders)
          .timeout(ApiConfig.requestTimeout);
      _process(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('No se pudo eliminar la evaluación.');
    }
  }
}
