import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/config.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  /// Returns true when a session was created immediately; false when the
  /// project requires email confirmation first.
  Future<bool> signUp({required String email, required String password, required String name}) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: AppConfig.authRedirect,
    );
    return res.session != null;
  }

  Future<void> signIn({required String email, required String password}) => _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) => _client.auth.resetPasswordForEmail(email.trim(), redirectTo: AppConfig.resetRedirect);

  Future<void> updatePassword(String password) => _client.auth.updateUser(UserAttributes(password: password));

  Future<void> deleteAccountRow() => _client.rpc('delete_my_account');
}
