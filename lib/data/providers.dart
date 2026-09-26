import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/location_service.dart';
import '../core/services/weather_service.dart';
import 'models/moment.dart';
import 'models/preferences.dart';
import 'repositories/auth_repository.dart';
import 'repositories/moment_repository.dart';
import 'repositories/preferences_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/storage_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));
final storageRepoProvider = Provider((ref) => StorageRepository(ref.watch(supabaseProvider)));
final momentRepoProvider = Provider((ref) => MomentRepository(ref.watch(supabaseProvider), ref.watch(storageRepoProvider)));
final prefsRepoProvider = Provider((ref) => PreferencesRepository(ref.watch(supabaseProvider)));
final profileRepoProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseProvider), ref.watch(storageRepoProvider)));
final locationServiceProvider = Provider((ref) => LocationService());
final weatherServiceProvider = Provider((ref) => WeatherService());

/// Emits on every sign-in / sign-out / token refresh.
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authRepoProvider).changes);

/// The signed-in user, or null.
final sessionUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepoProvider).currentUser;
});

class RecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    final sub = ref.watch(authRepoProvider).changes.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) state = true;
    });
    ref.onDispose(sub.cancel);
    return false;
  }

  void clear() => state = false;
}

final passwordRecoveryProvider = NotifierProvider<RecoveryNotifier, bool>(RecoveryNotifier.new);

// ── preferences ─────────────────────────────────────────────────────────
class PreferencesNotifier extends AsyncNotifier<UserPreferences?> {
  @override
  Future<UserPreferences?> build() async {
    final user = ref.watch(sessionUserProvider);
    if (user == null) return null;
    return ref.read(prefsRepoProvider).fetch(user.id);
  }

  /// Optimistic update; reverts and rethrows if the save fails.
  Future<void> edit(UserPreferences Function(UserPreferences) change) async {
    final user = ref.read(sessionUserProvider);
    final current = state.value;
    if (user == null || current == null) return;
    final next = change(current);
    state = AsyncData(next);
    try {
      await ref.read(prefsRepoProvider).save(user.id, next);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final preferencesProvider = AsyncNotifierProvider<PreferencesNotifier, UserPreferences?>(PreferencesNotifier.new);

/// Non-null view for widgets that just need to paint.
final prefsProvider = Provider<UserPreferences>((ref) => ref.watch(preferencesProvider).value ?? const UserPreferences());

// ── profile ─────────────────────────────────────────────────────────────
class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final user = ref.watch(sessionUserProvider);
    if (user == null) return null;
    return ref.read(profileRepoProvider).fetch(user.id);
  }

  Future<void> rename(String name) async {
    final user = ref.read(sessionUserProvider)!;
    await ref.read(profileRepoProvider).updateName(user.id, name);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setAvatar(Uint8List bytes, String contentType) async {
    final user = ref.read(sessionUserProvider)!;
    await ref.read(profileRepoProvider).uploadAvatar(user.id, bytes, contentType);
    ref.invalidateSelf();
    await future;
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

// ── moments ─────────────────────────────────────────────────────────────
class MomentsNotifier extends AsyncNotifier<List<Moment>> {
  @override
  Future<List<Moment>> build() async {
    final user = ref.watch(sessionUserProvider);
    if (user == null) return const [];
    return ref.read(momentRepoProvider).list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(momentRepoProvider).list());
  }

  /// Re-fetch one moment and splice it into the list (after create / edit).
  Future<Moment?> reload(String id) async {
    final m = await ref.read(momentRepoProvider).get(id);
    final list = [...(state.value ?? const <Moment>[])];
    list.removeWhere((e) => e.id == id);
    if (m != null) list.add(m);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(list);
    return m;
  }

  Future<void> delete(Moment m) async {
    await ref.read(momentRepoProvider).delete(m);
    state = AsyncData([...(state.value ?? const <Moment>[])]..removeWhere((e) => e.id == m.id));
  }
}

final momentsProvider = AsyncNotifierProvider<MomentsNotifier, List<Moment>>(MomentsNotifier.new);

final momentByIdProvider = Provider.family<Moment?, String>((ref, id) {
  final list = ref.watch(momentsProvider).value ?? const <Moment>[];
  for (final m in list) {
    if (m.id == id) return m;
  }
  return null;
});

/// Set right after a moment is created so Home can acknowledge it.
class LastCreatedNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final lastCreatedProvider = NotifierProvider<LastCreatedNotifier, String?>(LastCreatedNotifier.new);

// ── media ───────────────────────────────────────────────────────────────
final signedUrlProvider = FutureProvider.family<String, ({String bucket, String path})>((ref, k) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 40), link.close);
  return ref.watch(storageRepoProvider).signedUrl(k.bucket, k.path);
});

// ── weather (optional) ──────────────────────────────────────────────────
final weatherProvider = FutureProvider<Weather?>((ref) async {
  final prefs = ref.watch(prefsProvider);
  if (!prefs.weatherEnabled || !prefs.locationEnabled) return null;
  try {
    final pos = await ref.read(locationServiceProvider).position();
    return await ref.read(weatherServiceProvider).current(pos.latitude, pos.longitude);
  } catch (_) {
    return null; // weather is never required
  }
});
