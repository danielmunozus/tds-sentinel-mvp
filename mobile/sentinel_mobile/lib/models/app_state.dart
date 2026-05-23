// lib/models/app_state.dart — TDS Sentinel
// Singleton de sesión. Almacena cliente autenticado + Bearer token.
import 'package:flutter/foundation.dart';
import 'client.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  Client? _client;
  String? _token;

  Client? get client => _client;
  String? get token  => _token;
  bool get isLoggedIn => _client != null && _token != null;

  void login(Client client, String token) {
    _client = client;
    _token  = token;
    notifyListeners();
  }

  void logout() {
    _client = null;
    _token  = null;
    notifyListeners();
  }
}
