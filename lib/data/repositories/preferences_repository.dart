import '../../core/services/api_client.dart';
import '../models/preferences.dart';

class PreferencesRepository {
  PreferencesRepository(this._api);
  final ApiClient _api;

  Future<UserPreferences> fetch(String userId) async {
    final res = await _api.get('/api/preferences');
    return UserPreferences.fromJson(res['preferences'] as Map<String, dynamic>);
  }

  Future<void> save(String userId, UserPreferences p) => _api.put('/api/preferences', body: p.toJson());
}
