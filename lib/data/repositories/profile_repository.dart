import 'dart:typed_data';

import '../../core/services/api_client.dart';
import '../models/preferences.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<Profile> fetch(String userId) async {
    final res = await _api.get('/api/profile');
    return Profile.fromJson(res['profile'] as Map<String, dynamic>);
  }

  Future<void> updateName(String userId, String name) => _api.put('/api/profile', body: {'displayName': name.trim()});

  /// Returns the new signed avatar URL.
  Future<String> uploadAvatar(String userId, Uint8List bytes, String contentType) async {
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final res = await _api.upload('POST', '/api/profile/avatar', bytes: bytes, filename: 'avatar.$ext', contentType: contentType);
    return res['avatarUrl'] as String;
  }
}
