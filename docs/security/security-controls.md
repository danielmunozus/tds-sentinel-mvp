# TDS Sentinel — Security Controls

## Controles de seguridad implementados

### Backend (Flask + SQLite)

| Control | Implementación | Archivo |
|---------|---------------|---------|
| SQL Injection | Queries parametrizadas con `?` en todos los endpoints | `routes/assessments.py` |
| Secrets | Variables de entorno via `.env` + `python-dotenv` | `config.py` |
| CORS | Lista blanca de orígenes (`CORS_ORIGINS`), nunca `*` | `app.py` |
| Stack traces | Errores logueados internamente, JSON limpio al cliente | `app.py` |
| Input sanitization | Strip + eliminación de chars de control + longitud máxima | `routes/assessments.py` |
| Integridad | SHA-256 hash por evaluación | `routes/assessments.py` |
| Debug mode | `False` por defecto, solo `True` via `FLASK_DEBUG=true` en `.env` | `config.py` |
| Host binding | `127.0.0.1` en desarrollo — nunca `0.0.0.0` | `app.py` |
| Foreign keys | `PRAGMA foreign_keys = ON` en SQLite | `database.py` |
| Config fail-fast | `validate()` lanza error si falta `SECRET_KEY` | `config.py` |
| JSON only | Error handlers globales devuelven siempre JSON (nunca HTML) | `app.py` |

### Flutter (Mobile)

| Control | Implementación | Archivo |
|---------|---------------|---------|
| Validación de formulario | Campos requeridos + trim antes de enviar | `assessment_form_screen.dart` |
| Sin datos locales sensibles | No se persiste nada en el dispositivo | `api_service.dart` |
| Errores amigables | `ApiException` abstrae errores HTTP del usuario | `api_service.dart` |
| Timeout | `Duration(seconds: 15)` en todos los requests | `api_config.dart` |
| Confirmación de borrado | `AlertDialog` antes de DELETE | `assessment_history_screen.dart` |
| No logging de payloads | Sin `print` de respuestas completas en producción | `api_service.dart` |

### Pendiente para producción (fuera del MVP)

- Autenticación JWT o sesiones
- HTTPS con certificado válido (nginx + Let's Encrypt)
- Rate limiting en endpoints de escritura
- Audit log de operaciones
- Rotación de SECRET_KEY
- Migración de SQLite a PostgreSQL para concurrencia

## Guía para HTTPS en demo con Codespaces

Codespaces expone el puerto 5000 con HTTPS automáticamente a través de su proxy.
La URL pública del Codespace ya usa `https://`.

Para desarrollo local con certificado autofirmado (opcional):

```bash
# Generar certificado autofirmado (solo para demos locales)
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout backend/certs/key.pem \
  -out backend/certs/cert.pem \
  -days 365 -subj '/CN=localhost'

# En app.py, cambiar app.run() a:
app.run(host='127.0.0.1', port=5000, debug=False,
        ssl_context=('certs/cert.pem', 'certs/key.pem'))
```

> Los certificados autofirmados generan advertencias en el navegador y en Flutter.
> Para producción real, usar Let's Encrypt o un certificado de una CA reconocida.
