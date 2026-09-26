import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/preferences.dart';

class PreferencesRepository {
  PreferencesRepository(this._client);
  final SupabaseClient _client;

  Future<UserPreferences> fetch(String userId) async {
    final row = await _client.from('user_preferences').select().eq('user_id', userId).maybeSingle();
    if (row == null) {
      // Trigger normally creates it; recover if it is missing.
      final created = const UserPreferences();
      await save(userId, created);
      return created;
    }
    return UserPreferences.fromJson(row);
  }

  Future<void> save(String userId, UserPreferences p) => _client.from('user_preferences').upsert(p.toJson(userId));
}
