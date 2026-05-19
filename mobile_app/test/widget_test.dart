import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_mobile/main.dart';

void main() {
  testWidgets('App arranca y muestra el AppBar de Sentinel',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SentinelApp());
    // Verifica que el título de la app esté presente en el árbol de widgets.
    expect(find.text('TDS Sentinel'), findsOneWidget);
  });
}
