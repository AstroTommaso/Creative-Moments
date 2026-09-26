import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/drawing_export.dart';
import '../../core/utils/question_selector.dart';
import '../../data/models/drawing.dart';
import '../../data/models/moment.dart';
import '../../data/providers.dart';
import '../../data/repositories/moment_repository.dart';

enum SaveStatus { idle, dirty, saving, saved, error }

class PendingImage {
  const PendingImage({required this.id, required this.bytes, required this.ext, required this.contentType});
  final String id;
  final Uint8List bytes;
  final String ext, contentType;
}

class Place {
  const Place({required this.name, this.latitude, this.longitude});
  final String name;
  final double? latitude, longitude;
}

class Music {
  const Music({required this.title, this.artist, this.album, this.artworkUrl});
  final String title;
  final String? artist, album, artworkUrl;
}

class DraftState {
  const DraftState({
    required this.id,
    required this.type,
    required this.createdAt,
    this.persisted = false,
    this.isEditing = false,
    this.title = '',
    this.body = '',
    this.drawing,
    this.textCreationId,
    this.drawingCreationId,
    this.images = const [],
    this.pendingImages = const [],
    this.drawingMedia,
    this.inspirations = const [],
    this.mood,
    this.atmosphere,
    this.timeOfDay,
    this.place,
    this.music,
    this.prompts = const [],
    this.question,
    this.questionAnswer = '',
    this.shownQuestionIds = const {},
    this.status = SaveStatus.idle,
    this.error,
    this.active = true,
  });

  final String id;
  final CreationType type;
  final DateTime createdAt;
  final bool persisted, isEditing, active;
  final String title, body;
  final DrawingData? drawing;
  final String? textCreationId, drawingCreationId;
  final List<MediaItem> images;
  final List<PendingImage> pendingImages;
  final MediaItem? drawingMedia;
  final List<Inspiration> inspirations;
  final String? mood, atmosphere, timeOfDay;
  final Place? place;
  final Music? music;
  final List<PromptAnswer> prompts;
  final ({String id, String text})? question;
  final String questionAnswer;
  final Set<String> shownQuestionIds;
  final SaveStatus status;
  final String? error;

  bool get hasDrawing => drawing != null && !drawing!.isEmpty;
  bool get hasContent => title.trim().isNotEmpty || body.trim().isNotEmpty || hasDrawing || images.isNotEmpty || pendingImages.isNotEmpty;
  bool get unsaved => hasContent && (status == SaveStatus.dirty || status == SaveStatus.saving || status == SaveStatus.error);
  int get wordCount => body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;

  DraftState copyWith({
    bool? persisted,
    String? title,
    String? body,
    Object? drawing = _keep,
    String? textCreationId,
    String? drawingCreationId,
    List<MediaItem>? images,
    List<PendingImage>? pendingImages,
    Object? drawingMedia = _keep,
    List<Inspiration>? inspirations,
    Object? mood = _keep,
    Object? place = _keep,
    Object? music = _keep,
    List<PromptAnswer>? prompts,
    Object? question = _keep,
    String? questionAnswer,
    Set<String>? shownQuestionIds,
    SaveStatus? status,
    Object? error = _keep,
    bool? active,
  }) => DraftState(
    id: id,
    type: type,
    createdAt: createdAt,
    isEditing: isEditing,
    persisted: persisted ?? this.persisted,
    title: title ?? this.title,
    body: body ?? this.body,
    drawing: identical(drawing, _keep) ? this.drawing : drawing as DrawingData?,
    textCreationId: textCreationId ?? this.textCreationId,
    drawingCreationId: drawingCreationId ?? this.drawingCreationId,
    images: images ?? this.images,
    pendingImages: pendingImages ?? this.pendingImages,
    drawingMedia: identical(drawingMedia, _keep) ? this.drawingMedia : drawingMedia as MediaItem?,
    inspirations: inspirations ?? this.inspirations,
    mood: identical(mood, _keep) ? this.mood : mood as String?,
    atmosphere: atmosphere,
    timeOfDay: timeOfDay,
    place: identical(place, _keep) ? this.place : place as Place?,
    music: identical(music, _keep) ? this.music : music as Music?,
    prompts: prompts ?? this.prompts,
    question: identical(question, _keep) ? this.question : question as ({String id, String text})?,
    questionAnswer: questionAnswer ?? this.questionAnswer,
    shownQuestionIds: shownQuestionIds ?? this.shownQuestionIds,
    status: status ?? this.status,
    error: identical(error, _keep) ? this.error : error as String?,
    active: active ?? this.active,
  );
}

const _keep = Object();
const _uuid = Uuid();

/// In-memory working copy of the moment being created or edited. The backend
/// is the source of truth: this state is synced by debounced autosave, and
/// the UI only ever says "Saved" once the server confirmed it.
class DraftNotifier extends Notifier<DraftState> {
  Timer? _debounce, _retry;
  int _rev = 0;
  bool _saving = false, _again = false;
  bool _drawingPngStale = false;
  QuestionSelector _selector = QuestionSelector();

  static const debounce = Duration(milliseconds: 1600);
  static const retryEvery = Duration(seconds: 10);

  @override
  DraftState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _retry?.cancel();
    });
    return DraftState(id: _uuid.v4(), type: CreationType.freeform, createdAt: DateTime.now(), active: false);
  }

  /// For tests: deterministic question picking.
  void useSelector(QuestionSelector s) => _selector = s;

  void start(CreationType type) {
    _debounce?.cancel();
    _retry?.cancel();
    _rev = 0;
    _drawingPngStale = false;
    final now = DateTime.now();
    state = DraftState(
      id: _uuid.v4(),
      type: type,
      createdAt: now,
      textCreationId: _uuid.v4(),
      drawingCreationId: _uuid.v4(),
      atmosphere: ref.read(prefsProvider).atmosphere,
      timeOfDay: timeOfDayFor(now),
    );
  }

  void loadExisting(Moment m) {
    _debounce?.cancel();
    _retry?.cancel();
    _rev = 0;
    _drawingPngStale = false;
    final text = m.creations.where((c) => c.type == 'text').firstOrNull;
    final draw = m.creations.where((c) => c.type == 'drawing').firstOrNull;
    state = DraftState(
      id: m.id,
      type: m.type,
      createdAt: m.createdAt,
      persisted: true,
      isEditing: true,
      title: m.title,
      body: text?.textContent ?? '',
      drawing: draw?.drawing,
      textCreationId: text?.id ?? _uuid.v4(),
      drawingCreationId: draw?.id ?? _uuid.v4(),
      images: m.images,
      drawingMedia: m.media.where((e) => e.type == 'drawing').firstOrNull,
      inspirations: m.inspirations,
      mood: m.mood,
      atmosphere: m.atmosphere,
      timeOfDay: m.timeOfDay,
      place: m.hasLocation ? Place(name: m.locationName!, latitude: m.latitude, longitude: m.longitude) : null,
      music: m.hasMusic ? Music(title: m.musicTitle!, artist: m.musicArtist, album: m.musicAlbum, artworkUrl: m.musicArtworkUrl) : null,
      prompts: m.prompts,
      status: SaveStatus.saved,
    );
  }

  void clear() {
    _debounce?.cancel();
    _retry?.cancel();
    state = state.copyWith(active: false);
  }

  // ── edits ────────────────────────────────────────────────────────────
  void _touch(DraftState next) {
    _rev++;
    state = next.copyWith(status: SaveStatus.dirty, error: null);
    _debounce?.cancel();
    _debounce = Timer(debounce, () => save());
  }

  void setTitle(String v) => v == state.title ? null : _touch(state.copyWith(title: v));
  void setBody(String v) => v == state.body ? null : _touch(state.copyWith(body: v));

  void setDrawing(DrawingData? d) {
    _drawingPngStale = true;
    _touch(state.copyWith(drawing: d));
  }

  void addImage(PendingImage img) => _touch(state.copyWith(pendingImages: [...state.pendingImages, img]));

  void removePendingImage(String id) => _touch(state.copyWith(pendingImages: state.pendingImages.where((e) => e.id != id).toList()));

  Future<void> removeSavedImage(MediaItem m) async {
    try {
      await ref.read(momentRepoProvider).removeMedia(m);
      state = state.copyWith(images: state.images.where((e) => e.id != m.id).toList());
    } catch (e) {
      state = state.copyWith(error: friendlyError(e));
    }
  }

  void toggleInspiration(String type, {String? name}) {
    final list = [...state.inspirations];
    final i = list.indexWhere((e) => e.type == type);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.add(Inspiration(type: type, name: name ?? labelFor(inspirationOptions, type)));
    }
    _touch(state.copyWith(inspirations: list));
  }

  void setCustomInspiration(String text) {
    final list = state.inspirations.where((e) => e.type != 'other').toList();
    if (text.trim().isNotEmpty) list.add(Inspiration(type: 'other', name: text.trim()));
    _touch(state.copyWith(inspirations: list));
  }

  void setMood(String? mood) => _touch(state.copyWith(mood: mood == null || mood.trim().isEmpty ? null : mood.trim()));
  void setPlace(Place? p) => _touch(state.copyWith(place: p));
  void setMusic(Music? m) => _touch(state.copyWith(music: m));

  // ── questions ────────────────────────────────────────────────────────
  Set<String> get _envs => ref.read(prefsProvider).activeEnvironments.toSet();

  /// Picks a new contextual question. Returns false if the library is exhausted.
  bool nextQuestion() {
    final s = state;
    final q = _selector.pick(
      QuestionContext(type: s.type.name, inspirations: s.inspirations.map((e) => e.type).toSet(), mood: s.mood, timeOfDay: s.timeOfDay, environments: _envs),
      exclude: s.shownQuestionIds,
    );
    if (q == null) return false;
    state = state.copyWith(question: (id: q.id, text: q.text), questionAnswer: '', shownQuestionIds: {...s.shownQuestionIds, q.id});
    return true;
  }

  void setAnswer(String v) => state = state.copyWith(questionAnswer: v);

  // ── persistence ──────────────────────────────────────────────────────
  Future<void> save() async {
    _debounce?.cancel();
    if (_saving) {
      _again = true;
      return;
    }
    if (!state.active) return;
    _saving = true;
    try {
      do {
        _again = false;
        await _persist();
      } while (_again);
    } finally {
      _saving = false;
    }
  }

  Future<void> _persist() async {
    final user = ref.read(sessionUserProvider);
    final s = state;
    if (user == null) return;
    if (!s.hasContent && !s.persisted) {
      state = state.copyWith(status: SaveStatus.idle);
      return;
    }
    final rev = _rev;
    state = state.copyWith(status: SaveStatus.saving);
    try {
      final repo = ref.read(momentRepoProvider);
      final hasText = s.body.isNotEmpty || s.type.isText;
      await repo.saveCore(
        MomentCoreSave(
          id: s.id,
          userId: user.id,
          title: s.title.trim(),
          creationType: s.type.name,
          createdAt: s.createdAt,
          mood: s.mood,
          atmosphere: s.atmosphere,
          timeOfDay: s.timeOfDay,
          locationName: s.place?.name,
          latitude: s.place?.latitude,
          longitude: s.place?.longitude,
          musicTitle: s.music?.title,
          musicArtist: s.music?.artist,
          musicAlbum: s.music?.album,
          musicArtworkUrl: s.music?.artworkUrl,
          textCreationId: hasText ? s.textCreationId : null,
          text: s.body,
          drawingCreationId: s.drawing != null ? s.drawingCreationId : null,
          drawing: s.drawing,
        ),
      );
      var images = state.images;
      var pending = state.pendingImages;
      for (final img in s.pendingImages) {
        final saved = await repo.addMedia(userId: user.id, momentId: s.id, type: 'image', bytes: img.bytes, ext: img.ext, contentType: img.contentType);
        images = [...images, saved];
        pending = pending.where((e) => e.id != img.id).toList();
        state = state.copyWith(images: images, pendingImages: pending);
      }
      final changed = rev != _rev;
      state = state.copyWith(persisted: true, status: changed ? SaveStatus.dirty : SaveStatus.saved, error: null);
      _retry?.cancel();
      if (changed) _again = true;
    } catch (e) {
      state = state.copyWith(status: SaveStatus.error, error: friendlyError(e));
      _retry?.cancel();
      _retry = Timer(retryEvery, () => save());
    }
  }

  /// Final save: core, details, drawing PNG. Throws a friendly [AppError].
  Future<String> finish() async {
    _debounce?.cancel();
    _retry?.cancel();
    // wait for any autosave in flight
    while (_saving) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    _saving = true;
    try {
      await _persist();
      if (state.status == SaveStatus.error) throw AppError(state.error ?? 'Your changes could not be saved.');
      final repo = ref.read(momentRepoProvider);
      final user = ref.read(sessionUserProvider)!;
      final s = state;
      try {
        final prompts = [...s.prompts];
        final q = s.question;
        if (q != null && s.questionAnswer.trim().isNotEmpty) {
          prompts.add(PromptAnswer(id: _uuid.v4(), question: q.text, answer: s.questionAnswer.trim()));
        }
        await repo.saveDetails(s.id, s.inspirations, prompts);
        state = state.copyWith(prompts: prompts, question: null, questionAnswer: '');
        if (s.hasDrawing && (_drawingPngStale || s.drawingMedia == null)) {
          final png = await renderDrawingPng(s.drawing!);
          if (s.drawingMedia != null) {
            final updated = await repo.replaceMedia(s.drawingMedia!, png, contentType: 'image/png');
            state = state.copyWith(drawingMedia: updated);
          } else {
            final m = await repo.addMedia(
              userId: user.id,
              momentId: s.id,
              type: 'drawing',
              bytes: png,
              ext: 'png',
              contentType: 'image/png',
              fileName: 'drawing.png',
              metadata: {'width': s.drawing!.width, 'height': s.drawing!.height},
            );
            state = state.copyWith(drawingMedia: m);
          }
          _drawingPngStale = false;
        }
      } catch (e) {
        throw AppError.from(e);
      }
      final wasNew = !s.isEditing;
      await ref.read(momentsProvider.notifier).reload(s.id);
      if (wasNew) ref.read(lastCreatedProvider.notifier).set(s.id);
      state = state.copyWith(status: SaveStatus.saved);
      return s.id;
    } finally {
      _saving = false;
    }
  }

  /// Leaving the editor: keep whatever autosave stored in the moments list.
  Future<void> syncList() async {
    if (state.persisted) await ref.read(momentsProvider.notifier).reload(state.id);
  }

  /// Abandon a brand-new moment entirely (removes anything autosave stored).
  Future<void> discard() async {
    _debounce?.cancel();
    _retry?.cancel();
    final s = state;
    state = s.copyWith(active: false);
    if (s.persisted && !s.isEditing) {
      try {
        final m = await ref.read(momentRepoProvider).get(s.id);
        if (m != null) await ref.read(momentsProvider.notifier).delete(m);
      } catch (_) {}
    }
  }
}

final draftProvider = NotifierProvider<DraftNotifier, DraftState>(DraftNotifier.new);
