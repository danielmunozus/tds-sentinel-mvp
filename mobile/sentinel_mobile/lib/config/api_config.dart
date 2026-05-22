// lib/config/api_config.dart — TDS Sentinel
// Configuración centralizada de la API.
// Nunca dispersar URLs de endpoints en los screens.

class ApiConfig {
  ApiConfig._(); // Clase no instanciable

  static const String baseUrl = 'https://solid-cod-v6g47jv7qvxjhp996-5000.app.github.dev/api';

  // Endpoints
  static const String health      = '$baseUrl/health';
  static const String packs       = '$baseUrl/packs';
  static const String assessments = '$baseUrl/assessments';

  static String assessmentById(int id) => '$assessments/$id';

  // Timeout para requests HTTP
  static const Duration requestTimeout = Duration(seconds: 15);
}
