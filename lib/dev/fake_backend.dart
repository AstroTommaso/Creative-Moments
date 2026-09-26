// DEVELOPMENT / TEST ONLY.
//
// An in-memory stand-in for the Supabase repositories so the UI can be run and
// tested without a project. Nothing in the production entrypoint (main.dart)
// imports this file. It is deliberately NOT a persistent store.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/misc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/catalog.dart';
import '../data/models/drawing.dart';
import '../data/models/moment.dart';
import '../data/models/preferences.dart';
import '../data/providers.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/moment_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/storage_repository.dart';

const _uuid = Uuid();

class FakeBackend {
  final users = <String, ({String id, String password, String name})>{}; // by email
  String? currentEmail;
  final prefs = <String, UserPreferences>{};
  final profiles = <String, Profile>{};
  final moments = <String, Moment>{}; // by id
  final files = <String, Uint8List>{};
  final auth = StreamController<AuthState>.broadcast();

  /// When true every write throws, to exercise offline / error handling.
  bool offline = false;

  User? get currentUser {
    final e = currentEmail;
    if (e == null) return null;
    final u = users[e]!;
    return User(
      id: u.id,
      appMetadata: const {},
      userMetadata: {'display_name': u.name},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: e,
    );
  }

  void _check() {
    if (offline) throw const _Offline();
  }

  List<Override> get overrides => [
    authRepoProvider.overrideWithValue(FakeAuthRepository(this)),
    prefsRepoProvider.overrideWithValue(FakePreferencesRepository(this)),
    profileRepoProvider.overrideWithValue(FakeProfileRepository(this)),
    storageRepoProvider.overrideWithValue(FakeStorageRepository(this)),
    momentRepoProvider.overrideWithValue(FakeMomentRepository(this)),
  ];

  /// Pre-creates a demo account (not signed in) with a few moments.
  void createDemoAccount({bool onboarded = true}) {
    const email = 'demo@creative.moments';
    final id = _uuid.v4();
    users[email] = (id: id, password: 'demo-password', name: 'Astro');
    profiles[id] = Profile(id: id, displayName: 'Astro');
    prefs[id] = UserPreferences(onboarded: onboarded, environments: const ['moon', 'stars', 'city', 'rain']);
    if (onboarded) seed(id);
  }

  /// A few moments so a fresh dev session has something to explore.
  void seed(String userId) {
    final now = DateTime.now();
    Moment m(
      String title,
      CreationType type, {
      String? mood,
      String tod = 'night',
      int daysAgo = 0,
      int hour = 23,
      String text = '',
      List<String> insp = const [],
      String? place,
      String? song,
      String? artist,
      DrawingData? drawing,
      String? answer,
    }) {
      final id = _uuid.v4();
      final at = DateTime(now.year, now.month, now.day, hour, 12).subtract(Duration(days: daysAgo));
      return Moment(
        id: id,
        userId: userId,
        title: title,
        type: type,
        mood: mood,
        atmosphere: 'dreamy',
        timeOfDay: tod,
        locationName: place,
        musicTitle: song,
        musicArtist: artist,
        createdAt: at,
        updatedAt: at,
        creations: [
          if (text.isNotEmpty) Creation(id: _uuid.v4(), momentId: id, type: 'text', textContent: text, createdAt: at),
          if (drawing != null) Creation(id: _uuid.v4(), momentId: id, type: 'drawing', drawing: drawing, createdAt: at),
        ],
        inspirations: [for (final i in insp) Inspiration(type: i, name: labelFor(inspirationOptions, i))],
        prompts: answer == null ? const [] : [PromptAnswer(id: _uuid.v4(), question: 'Is the rain part of what you are trying to say?', answer: answer)],
      );
    }

    DrawingData sketch() {
      final strokes = <Stroke>[];
      for (var k = 0; k < 6; k++) {
        strokes.add(
          Stroke(
            tool: BrushTool.brush,
            color: [0xFFE9C98F, 0xFFB59CFF, 0xFFF3EFE8][k % 3],
            width: 5,
            points: [for (var i = 0; i <= 30; i++) Offset(30 + i * 8.0, 120 + k * 22 + (i % 2 == 0 ? 6 : -6) * (k + 1) * 0.6 + (i * i) * 0.02)],
          ),
        );
      }
      strokes.add(Stroke(tool: BrushTool.pencil, color: 0xFFF3EFE8, width: 2, points: [for (var i = 0; i <= 40; i++) Offset(190.0, 60.0 + i)]));
      return DrawingData(width: 300, height: 360, background: 0xFF12142A, strokes: strokes);
    }

    for (final x in [
      m(
        'Loneliness, but peaceful',
        CreationType.drawing,
        mood: 'peaceful',
        insp: ['moon', 'city', 'music'],
        place: 'Milano, Italia',
        song: 'Nuvole Bianche',
        artist: 'Ludovico Einaudi',
        drawing: sketch(),
        answer: 'Loneliness, but peaceful.',
      ),
      m(
        'Rain on the window',
        CreationType.writing,
        mood: 'melancholic',
        daysAgo: 2,
        hour: 22,
        insp: ['rain', 'memory'],
        text: 'The rain keeps asking the same quiet question, and the glass answers with a line that never finishes.\n\nI want to write like this: slowly, with no one waiting.',
      ),
      m(
        '',
        CreationType.letter,
        mood: 'nostalgic',
        tod: 'sunset',
        daysAgo: 5,
        hour: 18,
        insp: ['person', 'memory'],
        text: 'Dear you,\nI found the photograph of the sea again.',
      ),
      m(
        'Field notes',
        CreationType.idea,
        mood: 'inspired',
        tod: 'day',
        daysAgo: 9,
        hour: 14,
        insp: ['nature', 'flowers'],
        text: 'A garden where every flower is a different sentence.',
      ),
      m('Morning light', CreationType.story, mood: 'calm', tod: 'dawn', daysAgo: 12, hour: 7, insp: ['stars', 'moon'], text: 'She woke before the birds.'),
      m('Static', CreationType.writing, mood: 'lonely', daysAgo: 15, hour: 1, insp: ['city', 'music'], text: 'Neon hum.'),
    ]) {
      moments[x.id] = x;
    }
  }
}

class _Offline implements Exception {
  const _Offline();
  @override
  String toString() => 'SocketException: offline';
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.b);
  final FakeBackend b;

  @override
  User? get currentUser => b.currentUser;

  @override
  Stream<AuthState> get changes => b.auth.stream;

  @override
  Future<bool> signUp({required String email, required String password, required String name}) async {
    b._check();
    if (b.users.containsKey(email.trim())) throw const AuthException('User already registered');
    final id = _uuid.v4();
    b.users[email.trim()] = (id: id, password: password, name: name.trim());
    b.profiles[id] = Profile(id: id, displayName: name.trim());
    b.prefs[id] = const UserPreferences();
    b.currentEmail = email.trim();
    b.auth.add(AuthState(AuthChangeEvent.signedIn, null));
    return true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    b._check();
    final u = b.users[email.trim()];
    if (u == null || u.password != password) throw const AuthException('Invalid login credentials');
    b.currentEmail = email.trim();
    b.auth.add(AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<void> signOut() async {
    b.currentEmail = null;
    b.auth.add(AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> sendPasswordReset(String email) async => b._check();

  @override
  Future<void> updatePassword(String password) async => b._check();

  @override
  Future<void> deleteAccountRow() async {
    final e = b.currentEmail;
    if (e == null) return;
    final id = b.users[e]!.id;
    b.moments.removeWhere((_, m) => m.userId == id);
    b.users.remove(e);
    b.currentEmail = null;
  }
}

class FakePreferencesRepository implements PreferencesRepository {
  FakePreferencesRepository(this.b);
  final FakeBackend b;

  @override
  Future<UserPreferences> fetch(String userId) async {
    b._check();
    return b.prefs[userId] ?? const UserPreferences();
  }

  @override
  Future<void> save(String userId, UserPreferences p) async {
    b._check();
    b.prefs[userId] = p;
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.b);
  final FakeBackend b;

  @override
  Future<Profile> fetch(String userId) async => b.profiles[userId] ?? Profile(id: userId);

  @override
  Future<void> updateName(String userId, String name) async {
    b._check();
    b.profiles[userId] = Profile(id: userId, displayName: name.trim(), avatarUrl: b.profiles[userId]?.avatarUrl);
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List bytes, String contentType) async {
    b._check();
    final path = '$userId/avatar/avatar.png';
    b.files[path] = bytes;
    b.profiles[userId] = Profile(id: userId, displayName: b.profiles[userId]?.displayName ?? '', avatarUrl: path);
    return path;
  }
}

class FakeStorageRepository implements StorageRepository {
  FakeStorageRepository(this.b);
  final FakeBackend b;

  @override
  Future<String> signedUrl(String bucket, String path) async => 'about:blank#$path';

  @override
  Future<void> upload(String bucket, String path, Uint8List bytes, {required String contentType, bool upsert = false}) async {
    b._check();
    b.files[path] = bytes;
  }

  @override
  Future<void> remove(String bucket, List<String> paths) async {
    for (final p in paths) {
      b.files.remove(p);
    }
  }

  @override
  Future<List<String>> listAllForUser(String bucket, String userId) async => b.files.keys.where((k) => k.startsWith('$userId/')).toList();
}

class FakeMomentRepository implements MomentRepository {
  FakeMomentRepository(this.b);
  final FakeBackend b;

  @override
  Future<List<Moment>> list({int limit = 500}) async {
    b._check();
    final l = b.moments.values.toList()..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return l.take(limit).toList();
  }

  @override
  Future<Moment?> get(String id) async {
    b._check();
    return b.moments[id];
  }

  @override
  Future<void> saveCore(MomentCoreSave s) async {
    b._check();
    final old = b.moments[s.id];
    final creations = <Creation>[
      if (s.textCreationId != null) Creation(id: s.textCreationId!, momentId: s.id, type: 'text', textContent: s.text ?? '', createdAt: s.createdAt),
      if (s.drawingCreationId != null && s.drawing != null)
        Creation(id: s.drawingCreationId!, momentId: s.id, type: 'drawing', drawing: s.drawing, createdAt: s.createdAt),
    ];
    b.moments[s.id] = Moment(
      id: s.id,
      userId: s.userId,
      title: s.title,
      type: CreationType.parse(s.creationType),
      mood: s.mood,
      atmosphere: s.atmosphere,
      timeOfDay: s.timeOfDay,
      locationName: s.locationName,
      latitude: s.latitude,
      longitude: s.longitude,
      musicTitle: s.musicTitle,
      musicArtist: s.musicArtist,
      musicAlbum: s.musicAlbum,
      musicArtworkUrl: s.musicArtworkUrl,
      createdAt: s.createdAt,
      updatedAt: DateTime.now(),
      creations: creations,
      inspirations: old?.inspirations ?? const [],
      prompts: old?.prompts ?? const [],
      media: old?.media ?? const [],
    );
  }

  @override
  Future<void> saveDetails(String momentId, List<Inspiration> inspirations, List<PromptAnswer> prompts) async {
    b._check();
    final m = b.moments[momentId];
    if (m == null) throw StateError('moment not found');
    b.moments[momentId] = Moment(
      id: m.id,
      userId: m.userId,
      title: m.title,
      type: m.type,
      mood: m.mood,
      atmosphere: m.atmosphere,
      timeOfDay: m.timeOfDay,
      locationName: m.locationName,
      latitude: m.latitude,
      longitude: m.longitude,
      musicTitle: m.musicTitle,
      musicArtist: m.musicArtist,
      musicAlbum: m.musicAlbum,
      musicArtworkUrl: m.musicArtworkUrl,
      createdAt: m.createdAt,
      updatedAt: DateTime.now(),
      creations: m.creations,
      inspirations: inspirations,
      prompts: prompts,
      media: m.media,
    );
  }

  @override
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
    b._check();
    final path = '$userId/$momentId/${fileName ?? '${DateTime.now().microsecondsSinceEpoch}.$ext'}';
    b.files[path] = bytes;
    final item = MediaItem(id: _uuid.v4(), momentId: momentId, type: type, storagePath: path);
    final m = b.moments[momentId]!;
    b.moments[momentId] = Moment(
      id: m.id,
      userId: m.userId,
      title: m.title,
      type: m.type,
      mood: m.mood,
      atmosphere: m.atmosphere,
      timeOfDay: m.timeOfDay,
      locationName: m.locationName,
      latitude: m.latitude,
      longitude: m.longitude,
      musicTitle: m.musicTitle,
      musicArtist: m.musicArtist,
      musicAlbum: m.musicAlbum,
      musicArtworkUrl: m.musicArtworkUrl,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      creations: m.creations,
      inspirations: m.inspirations,
      prompts: m.prompts,
      media: [...m.media, item],
    );
    return item;
  }

  @override
  Future<void> removeMedia(MediaItem item) async {
    b._check();
    b.files.remove(item.storagePath);
    final m = b.moments[item.momentId];
    if (m == null) return;
    b.moments[m.id] = Moment(
      id: m.id,
      userId: m.userId,
      title: m.title,
      type: m.type,
      mood: m.mood,
      atmosphere: m.atmosphere,
      timeOfDay: m.timeOfDay,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      creations: m.creations,
      inspirations: m.inspirations,
      prompts: m.prompts,
      media: m.media.where((e) => e.id != item.id).toList(),
    );
  }

  @override
  Future<void> delete(Moment m) async {
    b._check();
    b.moments.remove(m.id);
  }

  @override
  Future<void> deleteAll(String userId) async {
    b._check();
    b.moments.removeWhere((_, m) => m.userId == userId);
  }
}
