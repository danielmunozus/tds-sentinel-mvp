// test/login_screen_test.dart — TDS Sentinel
//
// Tests de widget para LoginScreen.
// Cubre:
//   ✓ Renderizado de los campos email y contraseña
//   ✓ Botones "Iniciar sesión" y "Solicitar acceso"
//   ✓ Enlace "¿Olvidaste tu contraseña?"
//   ✓ Validación: email vacío → error
//   ✓ Validación: email sin @ → error
//   ✓ Validación: contraseña vacía → error
//   ✓ Formulario válido: no hay errores de validación
//   ✓ Toggle de visibilidad de contraseña (obscureText)
//   ✓ Login exitoso → navega a HomeScreen
//   ✓ Login fallido → muestra mensaje de error de la API
//   ✓ Estado de carga: botón deshabilitado durante la petición

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sentinel_mobile/screens/login_screen.dart';
import 'package:sentinel_mobile/services/api_service.dart';
import 'package:sentinel_mobile/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de prueba
// ─────────────────────────────────────────────────────────────────────────────

const _kEmail    = 'usuario@tdsinnovate.com';
const _kPassword = 'Password123!';

const _kClientJson = '''
{
  "id": 1,
  "company_name": "TDS Test Corp",
  "contact_name": "Test User",
  "email": "usuario@tdsinnovate.com",
  "phone": "+52 55 0000 0000",
  "bs_area": "Technology",
  "client_status": "enabled",
  "created_at": "2026-01-01T00:00:00Z"
}
''';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Inyecta un [MockClient] en el singleton [ApiService] y lo registra
/// como tearDown para restaurar un cliente real al finalizar cada test.
void _setMockHttp(MockClient mock) {
  ApiService.instance.httpClientForTesting = mock;
  addTearDown(() => ApiService.instance.httpClientForTesting = http.Client());
}

/// Crea un [MockClient] que responde con 200 + datos de cliente válidos.
MockClient _mockLoginOk() => MockClient((_) async => http.Response(
      _kClientJson,
      200,
      headers: {'content-type': 'application/json'},
    ));

/// Crea un [MockClient] que responde con 401 + mensaje de error.
MockClient _mockLoginError([String msg = 'Email o contraseña incorrectos.']) =>
    MockClient((_) async => http.Response(
          jsonEncode({'error': msg}),
          401,
          headers: {'content-type': 'application/json'},
        ));

/// Monta [LoginScreen] dentro de un [MaterialApp] con el tema TDS.
Future<void> pumpLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      // Ruta de retorno simple para no necesitar HomeScreen completo
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const Scaffold(body: Text('HomeScreen')),
      },
      initialRoute: '/',
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Renderizado ────────────────────────────────────────────────────────────
  group('LoginScreen — Renderizado', () {
    testWidgets('muestra el título y subtítulo de la app', (tester) async {
      await pumpLogin(tester);
      expect(find.text('TDS Sentinel'), findsOneWidget);
      expect(find.text('Plataforma de Evaluación de Riesgo'), findsOneWidget);
    });

    testWidgets('muestra la tarjeta de inicio de sesión', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Iniciar sesión'), findsWidgets); // título + botón
      expect(find.text('Accede con tu cuenta TDS Sentinel'), findsOneWidget);
    });

    testWidgets('contiene dos campos de texto (email y contraseña)', (tester) async {
      await pumpLogin(tester);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('muestra el label "Email" en el primer campo', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('muestra el label "Contraseña" en el segundo campo', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Contraseña'), findsOneWidget);
    });

    testWidgets('muestra el enlace "¿Olvidaste tu contraseña?"', (tester) async {
      await pumpLogin(tester);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    });

    testWidgets('muestra el botón "Solicitar acceso"', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Solicitar acceso'), findsOneWidget);
    });

    testWidgets('el campo contraseña oculta el texto por defecto', (tester) async {
      await pumpLogin(tester);
      final passField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passField.obscureText, isTrue);
    });
  });

  // ── Validación de email ────────────────────────────────────────────────────
  group('LoginScreen — Validación de email', () {
    testWidgets('email vacío muestra error "El email es requerido."', (tester) async {
      await pumpLogin(tester);

      // Dejar email vacío y enviar
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump();

      expect(find.text('El email es requerido.'), findsOneWidget);
    });

    testWidgets('email sin @ muestra error "Ingresa un email válido."', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, 'no-es-email');
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump();

      expect(find.text('Ingresa un email válido.'), findsOneWidget);
    });

    testWidgets('email válido no muestra error de email', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump();

      expect(find.text('El email es requerido.'), findsNothing);
      expect(find.text('Ingresa un email válido.'), findsNothing);
    });
  });

  // ── Validación de contraseña ───────────────────────────────────────────────
  group('LoginScreen — Validación de contraseña', () {
    testWidgets('contraseña vacía muestra error "La contraseña es requerida."',
        (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      // Dejar contraseña vacía
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump();

      expect(find.text('La contraseña es requerida.'), findsOneWidget);
    });

    testWidgets('contraseña no vacía no muestra error', (tester) async {
      _setMockHttp(_mockLoginOk());
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, _kPassword);
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump();

      expect(find.text('La contraseña es requerida.'), findsNothing);
    });
  });

  // ── Toggle de visibilidad ─────────────────────────────────────────────────
  group('LoginScreen — Visibilidad de contraseña', () {
    testWidgets('el ícono de ojo muestra la contraseña al pulsarlo', (tester) async {
      await pumpLogin(tester);

      // Antes: contraseña oculta
      final passFieldBefore = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passFieldBefore.obscureText, isTrue);

      // Pulsar el ícono de visibilidad
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Después: contraseña visible
      final passFieldAfter = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passFieldAfter.obscureText, isFalse);
    });

    testWidgets('pulsando el ícono dos veces vuelve a ocultar la contraseña',
        (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      final passField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passField.obscureText, isTrue);
    });
  });

  // ── Flujo de login exitoso ─────────────────────────────────────────────────
  group('LoginScreen — Login exitoso', () {
    testWidgets('navega fuera del LoginScreen al recibir 200 de la API',
        (tester) async {
      _setMockHttp(_mockLoginOk());
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, _kPassword);
      await tester.tap(find.text('Iniciar sesión').last);

      // Esperar la respuesta async
      await tester.pump();        // primer frame (setState loading)
      await tester.pumpAndSettle(); // frames restantes (navegación)

      // LoginScreen ya no debe estar en el árbol
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('muestra indicador de carga mientras espera la respuesta',
        (tester) async {
      // Respuesta con delay para poder capturar el estado de carga
      final slowMock = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(
          _kClientJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      _setMockHttp(slowMock);
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, _kPassword);
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pump(); // un frame: setState(_loading = true)

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(); // terminar para no dejar timers colgados
    });
  });

  // ── Flujo de login fallido ─────────────────────────────────────────────────
  group('LoginScreen — Login fallido', () {
    testWidgets('muestra el mensaje de error devuelto por la API', (tester) async {
      _setMockHttp(_mockLoginError());
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, 'WrongPass!');
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pumpAndSettle();

      expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    });

    testWidgets('muestra el error de cuenta bloqueada', (tester) async {
      _setMockHttp(MockClient((_) async => http.Response(
            jsonEncode({'error': 'La cuenta está bloqueada. Contacte a soporte.'}),
            403,
            headers: {'content-type': 'application/json'},
          )));
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, _kPassword);
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pumpAndSettle();

      expect(
        find.text('La cuenta está bloqueada. Contacte a soporte.'),
        findsOneWidget,
      );
    });

    testWidgets('error de conexión muestra mensaje genérico', (tester) async {
      // Sin mock → http.Client() real fallará con SocketException → ApiException
      _setMockHttp(MockClient((_) async => throw Exception('Sin conexión')));
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, _kPassword);
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    });

    testWidgets('después de un error el botón vuelve a estar habilitado',
        (tester) async {
      _setMockHttp(_mockLoginError());
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, _kEmail);
      await tester.enterText(find.byType(TextFormField).last, 'WrongPass!');
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pumpAndSettle();

      // El botón vuelve a mostrar texto (no CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Iniciar sesión'), findsWidgets);
    });
  });
}
