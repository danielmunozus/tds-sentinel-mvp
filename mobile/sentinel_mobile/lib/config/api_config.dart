// lib/config/api_config.dart — TDS Sentinel
// Configuración centralizada de la API.
// Nunca dispersar URLs de endpoints en los screens.

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  ApiConfig._();

  // En web usa el mismo host que sirve la app (same-origin).
  // En móvil/desktop apunta a localhost para desarrollo.
  static String get baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port/api';
    }
    return 'http://localhost:5000/api';
  }

  static String get health      => '$baseUrl/health';
  static String get packs       => '$baseUrl/packs';
  static String get clients     => '$baseUrl/clients';
  static String get assessments => '$baseUrl/assessments';

  static String get login          => '$baseUrl/auth/login';
  static String get logout         => '$baseUrl/auth/logout';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get contact        => '$baseUrl/auth/contact';

  static String clientById(int id)          => '$clients/$id';
  static String clientAssessments(int id)   => '$clients/$id/assessments';
  static String assessmentById(int id)      => '$assessments/$id';

  static const Duration requestTimeout = Duration(seconds: 15);
}
