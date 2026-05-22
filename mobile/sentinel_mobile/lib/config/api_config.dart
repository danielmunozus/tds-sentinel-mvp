// lib/config/api_config.dart — TDS Sentinel
// Configuración centralizada de la API.
// Nunca dispersar URLs de endpoints en los screens.

class ApiConfig {
  ApiConfig._(); // Clase no instanciable

  // URL base local para desarrollo en macOS.
  // Si usas emulador Android, cambia a: http://10.0.2.2:5000/api
  // Si usas Codespaces, cambia a la URL pública del Codespace.
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  // Endpoints
  static const String health      = '$baseUrl/health';
  static const String packs       = '$baseUrl/packs';
  static const String assessments = '$baseUrl/assessments';

  static String assessmentById(int id) => '$assessments/$id';

  // Timeout para requests HTTP
  static const Duration requestTimeout = Duration(seconds: 15);
}
