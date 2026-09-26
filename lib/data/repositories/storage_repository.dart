import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Private buckets only; files are read through short-lived signed URLs.
class StorageRepository {
  StorageRepository(this._client);
  final SupabaseClient _client;

  static const mediaBucket = 'moment-media';
  static const avatarBucket = 'avatars';
  static const _ttl = 3600;

  final Map<String, ({String url, DateTime at})> _cache = {};

  Future<void> upload(String bucket, String path, Uint8List bytes, {required String contentType, bool upsert = false}) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: upsert),
        );
    _cache.remove('$bucket/$path');
  }

  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
    for (final p in paths) {
      _cache.remove('$bucket/$p');
    }
  }

  Future<String> signedUrl(String bucket, String path) async {
    final key = '$bucket/$path';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at).inSeconds < _ttl - 300) return hit.url;
    final url = await _client.storage.from(bucket).createSignedUrl(path, _ttl);
    _cache[key] = (url: url, at: DateTime.now());
    return url;
  }

  /// Lists every object under `<userId>/` in a bucket (used for account deletion).
  Future<List<String>> listAllForUser(String bucket, String userId) async {
    final out = <String>[];
    Future<void> walk(String folder) async {
      final items = await _client.storage.from(bucket).list(path: folder, searchOptions: const SearchOptions(limit: 1000));
      for (final i in items) {
        final full = '$folder/${i.name}';
        if (i.id == null) {
          await walk(full);
        } else {
          out.add(full);
        }
      }
    }

    await walk(userId);
    return out;
  }
}
