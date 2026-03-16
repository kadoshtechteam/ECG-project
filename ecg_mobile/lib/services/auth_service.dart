import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'database_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Hash password using SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Validate password strength
  String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(password)) {
      return 'Password must contain both letters and numbers';
    }
    return null;
  }

  // Register new user
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      // Input validation
      if (username.trim().isEmpty) {
        return AuthResult.failure('Username cannot be empty');
      }

      if (!_isValidEmail(email)) {
        return AuthResult.failure('Invalid email format');
      }

      String? passwordError = validatePassword(password);
      if (passwordError != null) {
        return AuthResult.failure(passwordError);
      }

      // Check if username already exists
      User? existingUsername = await _databaseHelper.getUserByUsername(
        username,
      );
      if (existingUsername != null) {
        return AuthResult.failure('Username already exists');
      }

      // Check if email already exists
      User? existingEmail = await _databaseHelper.getUserByEmail(email);
      if (existingEmail != null) {
        return AuthResult.failure('Email already exists');
      }

      // Create new user
      User newUser = User(
        username: username.trim(),
        email: email.trim().toLowerCase(),
        passwordHash: _hashPassword(password),
        createdAt: DateTime.now(),
      );

      int userId = await _databaseHelper.insertUser(newUser);
      newUser = newUser.copyWith(id: userId);

      return AuthResult.success('User registered successfully', newUser);
    } catch (e) {
      return AuthResult.failure('Registration failed: ${e.toString()}');
    }
  }

  // Login user
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      if (usernameOrEmail.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Username/email and password are required');
      }

      User? user;

      // Try to find user by email first, then by username
      if (_isValidEmail(usernameOrEmail)) {
        user = await _databaseHelper.getUserByEmail(
          usernameOrEmail.trim().toLowerCase(),
        );
      } else {
        user = await _databaseHelper.getUserByUsername(usernameOrEmail.trim());
      }

      if (user == null) {
        return AuthResult.failure('User not found');
      }

      // Verify password
      String hashedPassword = _hashPassword(password);
      if (user.passwordHash != hashedPassword) {
        return AuthResult.failure('Invalid password');
      }

      // Save user session
      _currentUser = user;
      await _saveUserSession(user);

      return AuthResult.success('Login successful', user);
    } catch (e) {
      return AuthResult.failure('Login failed: ${e.toString()}');
    }
  }

  // Logout user
  Future<void> logout() async {
    _currentUser = null;
    await _clearUserSession();
  }

  // Save user session to SharedPreferences
  Future<void> _saveUserSession(User user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user.id!);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    print('Auth Service: Session saved for user ${user.id} (${user.username})');
  }

  // Clear user session from SharedPreferences
  Future<void> _clearUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
    print('Auth Service: Session cleared');
  }

  // Restore user session on app startup
  Future<bool> restoreSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');

      print('Auth Service: Attempting to restore session, userId: $userId');

      if (userId != null) {
        User? user = await _databaseHelper.getUserById(userId);
        if (user != null) {
          _currentUser = user;
          print(
            'Auth Service: Session restored for user ${user.id} (${user.username})',
          );
          return true;
        } else {
          print('Auth Service: User $userId not found in database');
        }
      } else {
        print('Auth Service: No user ID found in preferences');
      }
      return false;
    } catch (e) {
      print('Auth Service: Error restoring session: $e');
      return false;
    }
  }

  // Update user profile
  Future<AuthResult> updateProfile({
    required String username,
    required String email,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('No user logged in');
      }

      if (username.trim().isEmpty) {
        return AuthResult.failure('Username cannot be empty');
      }

      if (!_isValidEmail(email)) {
        return AuthResult.failure('Invalid email format');
      }

      // Check if username is taken by another user
      User? existingUsername = await _databaseHelper.getUserByUsername(
        username,
      );
      if (existingUsername != null && existingUsername.id != _currentUser!.id) {
        return AuthResult.failure('Username already exists');
      }

      // Check if email is taken by another user
      User? existingEmail = await _databaseHelper.getUserByEmail(email);
      if (existingEmail != null && existingEmail.id != _currentUser!.id) {
        return AuthResult.failure('Email already exists');
      }

      // Update user
      User updatedUser = _currentUser!.copyWith(
        username: username.trim(),
        email: email.trim().toLowerCase(),
      );

      await _databaseHelper.updateUser(updatedUser);
      _currentUser = updatedUser;
      await _saveUserSession(updatedUser);

      return AuthResult.success('Profile updated successfully', updatedUser);
    } catch (e) {
      return AuthResult.failure('Profile update failed: ${e.toString()}');
    }
  }

  // Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('No user logged in');
      }

      // Verify current password
      String hashedCurrentPassword = _hashPassword(currentPassword);
      if (_currentUser!.passwordHash != hashedCurrentPassword) {
        return AuthResult.failure('Current password is incorrect');
      }

      // Validate new password
      String? passwordError = validatePassword(newPassword);
      if (passwordError != null) {
        return AuthResult.failure(passwordError);
      }

      // Update password
      User updatedUser = _currentUser!.copyWith(
        passwordHash: _hashPassword(newPassword),
      );

      await _databaseHelper.updateUser(updatedUser);
      _currentUser = updatedUser;

      return AuthResult.success('Password changed successfully', updatedUser);
    } catch (e) {
      return AuthResult.failure('Password change failed: ${e.toString()}');
    }
  }
}

// Authentication result class
class AuthResult {
  final bool success;
  final String message;
  final User? user;

  AuthResult._({required this.success, required this.message, this.user});

  factory AuthResult.success(String message, [User? user]) {
    return AuthResult._(success: true, message: message, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(success: false, message: message);
  }
}
