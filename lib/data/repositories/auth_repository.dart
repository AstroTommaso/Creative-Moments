import 'dart:async';

import '../../core/services/api_client.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._api) {
    _api.onUnauthorized = () {
      if (_currentUser != null) {
        _currentUser = null;
        _changes.add(const AppAuthChange(AppAuthEvent.signedOut));
      }
    };
  }
  final ApiClient _api;
  final _changes = StreamController<AppAuthChange>.broadcast();
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  Stream<AppAuthChange> get changes => _changes.stream;

  /// Loads a persisted session (if any) and resolves the current user. Call
  /// once at startup before the app renders anything auth-dependent.
  Future<void> restoreSession() async {
    await _api.loadToken();
    if (_api.token == null) return;
    try {
      final res = await _api.get('/api/auth/me');
      _currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    } catch (_) {
      await _api.setToken(null);
    }
  }

  Future<void> signUp({required String email, required String password, required String name}) async {
    final res = await _api.post('/api/auth/signup', body: {'email': email.trim(), 'password': password, 'name': name.trim()});
    await _api.setToken(res['token'] as String);
    _currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    _changes.add(const AppAuthChange(AppAuthEvent.signedIn));
  }

  Future<void> signIn({required String email, required String password}) async {
    final res = await _api.post('/api/auth/login', body: {'email': email.trim(), 'password': password});
    await _api.setToken(res['token'] as String);
    _currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    _changes.add(const AppAuthChange(AppAuthEvent.signedIn));
  }

  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Sign the device out locally regardless of whether the server call succeeded.
    }
    await _api.setToken(null);
    _currentUser = null;
    _changes.add(const AppAuthChange(AppAuthEvent.signedOut));
  }

  Future<void> sendPasswordReset(String email) => _api.post('/api/auth/forgot-password', body: {'email': email.trim()});

  /// Deletes the account and every piece of data it owns (server-side, atomic).
  Future<void> deleteAccountRow() => _api.delete('/api/account');
}
