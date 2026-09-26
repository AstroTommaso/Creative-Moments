import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/drawing.dart';
import '../models/moment.dart';
import 'storage_repository.dart';

/// Everything needed to persist the core of a moment (autosave payload).
class MomentCoreSave {
  MomentCoreSave({
    required this.id,
    required this.userId,
    required this.title,
    required this.creationType,
    required this.createdAt,
    this.mood,
    this.atmosphere,
    this.timeOfDay,
    this.locationName,
    this.latitude,
    this.longitude,
    this.musicTitle,
    this.musicArtist,
    this.musicAlbum,
    this.musicArtworkUrl,
    this.textCreationId,
    this.text,
    this.drawingCreationId,
    this.drawing,
  });
  final String id, userId, title, creationType;
  final DateTime createdAt;
  final String? mood, atmosphere, timeOfDay, locationName, musicTitle, musicArtist, musicAlbum, musicArtworkUrl;
  final double? latitude, longitude;
  final String? textCreationId, text, drawingCreationId;
  final DrawingData? drawing;
}

class MomentRepository {
  MomentRepository(this._client, this._storage);
  final SupabaseClient _client;
  final StorageRepository _storage;

  Future<List<Moment>> list({int limit = 500}) async {
    final rows = await _client.from('moments').select(Moment.select).order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) Moment.fromJson(r)];
  }

  Future<Moment?> get(String id) async {
    final row = await _client.from('moments').select(Moment.select).eq('id', id).maybeSingle();
    return row == null ? null : Moment.fromJson(row);
  }

  /// Idempotent: ids are generated on the client, so a retry after a dropped
  /// response cannot create duplicates.
  Future<void> saveCore(MomentCoreSave s) async {
    await _client.from('moments').upsert({
      'id': s.id,
      'user_id': s.userId,
      'title': s.title,
      'creation_type': s.creationType,
      'mood': s.mood,
      'atmosphere': s.atmosphere,
      'time_of_day': s.timeOfDay,
      'location_name': s.locationName,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'music_title': s.musicTitle,
      'music_artist': s.musicArtist,
      'music_album': s.musicAlbum,
      'music_artwork_url': s.musicArtworkUrl,
      'created_at': s.createdAt.toUtc().toIso8601String(),
    });
    final rows = <Map<String, dynamic>>[];
    if (s.textCreationId != null) {
      rows.add({'id': s.textCreationId, 'moment_id': s.id, 'type': 'text', 'text_content': s.text ?? ''});
    }
    if (s.drawingCreationId != null && s.drawing != null) {
      rows.add({'id': s.drawingCreationId, 'moment_id': s.id, 'type': 'drawing', 'drawing_data': s.drawing!.toJson()});
    }
    if (rows.isNotEmpty) await _client.from('creations').upsert(rows);
  }

  Future<void> saveDetails(String momentId, List<Inspiration> inspirations, List<PromptAnswer> prompts) => _client.rpc(
    'save_moment_details',
    params: {
      'p_moment_id': momentId,
      'p_inspirations': [for (final i in inspirations) i.toJson()],
      'p_prompts': [for (final p in prompts) p.toJson()],
    },
  );

  Future<MediaItem> addMedia({
    required String userId,
    required String momentId,
    required String type,
    required Uint8List bytes,
    required String ext,
    required String contentType,
    Map<String, dynamic> metadata = const {},
    String? fileName,
  }) async {
    final name = fileName ?? '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final path = '$userId/$momentId/$name';
    await _storage.upload(StorageRepository.mediaBucket, path, bytes, contentType: contentType, upsert: true);
    final row = await _client.from('media').insert({'moment_id': momentId, 'type': type, 'storage_path': path, 'metadata': metadata}).select().single();
    return MediaItem.fromJson(row);
  }

  Future<void> removeMedia(MediaItem m) async {
    await _client.from('media').delete().eq('id', m.id);
    await _storage.remove(StorageRepository.mediaBucket, [m.storagePath]);
  }

  Future<void> delete(Moment m) async {
    final paths = m.media.map((e) => e.storagePath).toList();
    await _client.from('moments').delete().eq('id', m.id);
    // Best effort: rows are gone, so a failure here only leaves orphan files.
    try {
      await _storage.remove(StorageRepository.mediaBucket, paths);
    } catch (_) {}
  }

  Future<void> deleteAll(String userId) async {
    final paths = await _storage.listAllForUser(StorageRepository.mediaBucket, userId);
    await _client.from('moments').delete().eq('user_id', userId);
    await _storage.remove(StorageRepository.mediaBucket, paths);
  }
}
