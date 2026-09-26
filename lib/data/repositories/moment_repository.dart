import 'dart:convert';
import 'dart:typed_data';

import '../../core/services/api_client.dart';
import '../models/drawing.dart';
import '../models/moment.dart';

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
  MomentRepository(this._api);
  final ApiClient _api;

  Future<List<Moment>> list({int limit = 500}) async {
    final res = await _api.get('/api/moments');
    return [for (final m in res['moments'] as List) Moment.fromJson(m as Map<String, dynamic>)];
  }

  Future<Moment?> get(String id) async {
    try {
      final res = await _api.get('/api/moments/$id');
      return Moment.fromJson(res['moment'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Idempotent: ids are generated on the client, so a retry after a dropped
  /// response cannot create duplicates (the backend upserts by this id).
  Future<void> saveCore(MomentCoreSave s) => _api.put(
    '/api/moments/${s.id}',
    body: {
      'title': s.title,
      'creationType': s.creationType,
      'createdAt': s.createdAt.toUtc().toIso8601String(),
      'mood': s.mood,
      'atmosphere': s.atmosphere,
      'timeOfDay': s.timeOfDay,
      'locationName': s.locationName,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'musicTitle': s.musicTitle,
      'musicArtist': s.musicArtist,
      'musicAlbum': s.musicAlbum,
      'musicArtworkUrl': s.musicArtworkUrl,
      if (s.textCreationId != null) 'text': {'id': s.textCreationId, 'content': s.text ?? ''},
      if (s.drawingCreationId != null && s.drawing != null) 'drawing': {'id': s.drawingCreationId, 'data': s.drawing!.toJson()},
    },
  );

  Future<void> saveDetails(String momentId, List<Inspiration> inspirations, List<PromptAnswer> prompts) => _api.put(
    '/api/moments/$momentId/details',
    body: {'inspirations': [for (final i in inspirations) i.toJson()], 'prompts': [for (final p in prompts) p.toJson()]},
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
    final res = await _api.upload(
      'POST',
      '/api/moments/$momentId/media',
      bytes: bytes,
      filename: fileName ?? 'upload.$ext',
      contentType: contentType,
      fields: {'type': type, if (metadata.isNotEmpty) 'metadata': jsonEncode(metadata)},
    );
    return MediaItem.fromJson(res['media'] as Map<String, dynamic>);
  }

  /// Overwrites an existing media item's file in place (same row, same
  /// storage path) — used when re-saving a drawing that already has a PNG.
  Future<MediaItem> replaceMedia(MediaItem existing, Uint8List bytes, {required String contentType}) async {
    final res = await _api.upload('PUT', '/api/media/${existing.id}', bytes: bytes, filename: 'drawing.png', contentType: contentType);
    return MediaItem.fromJson(res['media'] as Map<String, dynamic>);
  }

  Future<void> removeMedia(MediaItem m) => _api.delete('/api/media/${m.id}');

  Future<void> delete(Moment m) => _api.delete('/api/moments/${m.id}');

  Future<void> deleteAll(String userId) => _api.delete('/api/moments');
}
