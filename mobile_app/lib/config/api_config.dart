/// Configuración centralizada de conexión a la API Flask.
///
/// Para cambiar de entorno basta con descomentar la línea correspondiente
/// a [baseUrl]. Ningún otro archivo debe contener una URL de la API.
class ApiConfig {
  ApiConfig._(); // clase no instanciable

  // ── Seleccionar UNO según el entorno ──────────────────────────────────────

  /// Codespaces / máquina local / iOS Simulator / Flutter Web
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  /// Android Emulator (el alias 10.0.2.2 apunta al localhost del host)
  // static const String baseUrl = 'http://10.0.2.2:5000/api';

  /// Dispositivo físico en la misma red WiFi (reemplazar con la IP local del host)
  // static const String baseUrl = 'http://192.168.1.X:5000/api';

  /// Producción (reemplazar con el dominio real cuando esté desplegado)
  // static const String baseUrl = 'https://api.tdssentinel.com/api';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 10);
}
