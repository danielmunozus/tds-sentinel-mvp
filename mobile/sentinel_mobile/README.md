# TDS Sentinel — Flutter Web App

**Versión:** 3.2.0 · **Framework:** Flutter 3.x · **Target:** Web (Chrome / Safari)

Aplicación web compilada que forma parte de la plataforma TDS Sentinel. Se sirve directamente desde Flask como archivos estáticos — no requiere servidor separado.

---

## Estructura del código

```
lib/
├── main.dart                         Punto de entrada + MaterialApp
├── config/
│   └── api_config.dart               URLs centralizadas (same-origin en web)
├── theme/
│   └── app_theme.dart                Colores y tipografía TDS Innovate
├── models/
│   ├── client.dart                   DTO del cliente autenticado
│   ├── risk_assessment.dart          DTO de evaluación de riesgo
│   ├── assessment_pack.dart          DTO del pack de controles
│   └── app_state.dart                Estado global (ChangeNotifier) — token + client
├── services/
│   └── api_service.dart              Capa HTTP centralizada con Bearer token
└── screens/
    ├── login_screen.dart             Formulario de login
    ├── forgot_password_screen.dart   Solicitud de reset de contraseña
    ├── contact_form_screen.dart      Formulario de cotización (prospecto)
    ├── home_screen.dart              Dashboard post-login
    ├── pack_selection_screen.dart    Selección de Assessment Pack
    ├── assessment_form_screen.dart   Cuestionario de controles
    ├── assessment_result_screen.dart Score + recomendaciones
    └── assessment_history_screen.dart Historial + eliminación
```

---

## Autenticación

A partir de v3.1, el app usa Bearer token en todas las requests protegidas:

```dart
// Login — AppState almacena token automáticamente
final client = await ApiService.instance.login(email, password);

// Requests protegidas — _authHeaders incluye Authorization: Bearer <token>
final assessments = await ApiService.instance.fetchAssessments();

// Logout — invalida token en servidor y limpia AppState
await ApiService.instance.logout();
```

El token se obtiene al hacer login y se mantiene en memoria (`AppState`). No se persiste en almacenamiento local del dispositivo.

---

## Configuración de API

`api_config.dart` detecta automáticamente el entorno:

```dart
static String get baseUrl {
  if (kIsWeb) {
    // Same-origin: usa el mismo host que sirve la app
    final uri = Uri.base;
    return '${uri.scheme}://${uri.host}:${uri.port}/api';
  }
  // Móvil/Desktop: apunta a localhost (dev)
  return 'http://localhost:5000/api';
}
```

Para emulador Android, cambiar a `http://10.0.2.2:5000/api`.

---

## Desarrollo local

```bash
cd mobile/sentinel_mobile
flutter pub get
flutter run -d chrome    # web en navegador local
```

Asegurarse de que el backend Flask esté corriendo en `http://localhost:5000`.

---

## Recompilar build de producción

```bash
# Desde la raíz del proyecto
bash rebuild_web.sh
```

El script compila en modo release y genera `build/web/` — Flask sirve este directorio automáticamente.

> El build compilado está incluido en el repositorio. Solo es necesario recompilar si se modifica código Dart/Flutter.

---

## Controles de seguridad implementados

| Control | Detalle |
|---------|---------|
| Bearer token | Header `Authorization: Bearer <token>` en todas las requests protegidas |
| Same-origin | `baseUrl` derivado de `Uri.base` en web — sin URLs hardcodeadas |
| Validación local | Campos requeridos + trim antes de enviar al servidor |
| Sin persistencia sensible | Token y datos del cliente solo en memoria (`AppState`) |
| Errores amigables | `ApiException` abstrae errores HTTP del servidor |
| Timeout | 15 segundos en todos los requests |
| Confirmación de borrado | `AlertDialog` antes de ejecutar DELETE |
