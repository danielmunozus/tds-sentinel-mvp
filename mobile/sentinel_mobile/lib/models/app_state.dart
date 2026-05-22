// lib/models/app_state.dart — TDS Sentinel
// Singleton de sesión. Sin paquetes externos.
import 'package:flutter/foundation.dart';
import 'client.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  Client? _client;
  Client? get client => _client;
  bool get isLoggedIn => _client != null;

  void login(Client client) {
    _client = client;
    notifyListeners();
  }

  void logout() {
    _client = null;
    notifyListeners();
  }
}
