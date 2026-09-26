import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/preferences.dart';
import 'storage_repository.dart';

class ProfileRepository {
  ProfileRepository(this._client, this._storage);
  final SupabaseClient _client;
  final StorageRepository _storage;

  Future<Profile> fetch(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) {
      await _client.from('profiles').upsert({'id': userId});
      return Profile(id: userId);
    }
    return Profile.fromJson(row);
  }

  Future<void> updateName(String userId, String name) => _client.from('profiles').update({'display_name': name.trim()}).eq('id', userId);

  Future<String> uploadAvatar(String userId, Uint8List bytes, String contentType) async {
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$userId/avatar/avatar.$ext';
    await _storage.upload(StorageRepository.avatarBucket, path, bytes, contentType: contentType, upsert: true);
    await _client.from('profiles').update({'avatar_url': path}).eq('id', userId);
    return path;
  }
}
