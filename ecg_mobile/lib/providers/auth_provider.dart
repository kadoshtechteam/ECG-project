import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;
  bool get isLoggedIn => _authService.isLoggedIn;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _authService.restoreSession();

    _isLoading = false;
    notifyListeners();
  }

  Future<AuthResult> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    AuthResult result = await _authService.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );

    _isLoading = false;
    notifyListeners();

    return result;
  }

  Future<AuthResult> register(
    String username,
    String email,
    String password,
  ) async {
    _isLoading = true;
    notifyListeners();

    AuthResult result = await _authService.register(
      username: username,
      email: email,
      password: password,
    );

    _isLoading = false;
    notifyListeners();

    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }
}
