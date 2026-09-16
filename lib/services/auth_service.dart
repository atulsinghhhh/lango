import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase auth. Maps raw errors to user-friendly
/// messages so the UI never surfaces stack traces or internals (US-001/002).
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp(
      {required String email, required String password}) async {
    try {
      return await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  Future<AuthResponse> signIn(
      {required String email, required String password}) async {
    try {
      return await _client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  String _friendly(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || e.code == 'user_already_exists') {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (msg.contains('invalid login credentials') ||
        e.code == 'invalid_credentials') {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    if (msg.contains('password')) {
      return 'Password must be at least 8 characters.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client-side validation shared by signup/login forms.
class AuthValidators {
  static final _emailRe =
      RegExp(r"^[\w.!#$%&'*+/=?^`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$");

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }
}
