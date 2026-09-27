import '../../core/constants/catalog.dart';
import '../../l10n/app_localizations.dart';
import 'drawing.dart';

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
double? _d(dynamic v) => (v as num?)?.toDouble();

class Creation {
  const Creation({required this.id, required this.momentId, required this.type, this.textContent, this.drawing, required this.createdAt});
  final String id, momentId, type; // type: text | drawing | image | audio
  final String? textContent;
  final DrawingData? drawing;
  final DateTime createdAt;

  factory Creation.fromJson(Map<String, dynamic> j) => Creation(
    id: j['id'] as String,
    momentId: j['momentId'] as String,
    type: j['type'] as String,
    textContent: j['textContent'] as String?,
    drawing: j['drawingData'] == null ? null : DrawingData.fromJson(Map<String, dynamic>.from(j['drawingData'] as Map)),
    createdAt: _dt(j['createdAt']),
  );
}

class Inspiration {
  const Inspiration({required this.type, required this.name});
  final String type, name;
  factory Inspiration.fromJson(Map<String, dynamic> j) => Inspiration(type: j['type'] as String, name: j['name'] as String);
  Map<String, dynamic> toJson() => {'type': type, 'name': name};
  String get emoji => emojiFor(inspirationOptions, type);
}

class PromptAnswer {
  const PromptAnswer({required this.id, required this.question, this.answer});
  final String id, question;
  final String? answer;

  factory PromptAnswer.fromJson(Map<String, dynamic> j) => PromptAnswer(id: j['id'] as String, question: j['question'] as String, answer: j['answer'] as String?);
  Map<String, dynamic> toJson() => {'id': id, 'question': question, 'answer': answer};
}

class MediaItem {
  const MediaItem({required this.id, required this.momentId, required this.type, required this.storagePath, this.url});
  final String id, momentId, type, storagePath;
  /// Ready-to-use, short-lived signed URL, provided by the backend alongside
  /// every media item — the app never resolves storage paths itself.
  final String? url;

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id: j['id'] as String,
    momentId: j['momentId'] as String,
    type: j['type'] as String,
    storagePath: j['storagePath'] as String,
    url: j['url'] as String?,
  );
}

class Moment {
  const Moment({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
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
    required this.createdAt,
    required this.updatedAt,
    this.finishedAt,
    this.creations = const [],
    this.inspirations = const [],
    this.prompts = const [],
    this.media = const [],
  });

  final String id, userId, title;
  final CreationType type;
  final String? mood, atmosphere, timeOfDay, locationName, musicTitle, musicArtist, musicAlbum, musicArtworkUrl;
  final double? latitude, longitude;
  final DateTime createdAt, updatedAt;
  /// Set once the user explicitly finished it (details/save step); null
  /// means it only exists from autosave and is still a work in progress.
  final DateTime? finishedAt;
  final List<Creation> creations;
  final List<Inspiration> inspirations;
  final List<PromptAnswer> prompts;
  final List<MediaItem> media;

  factory Moment.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [for (final e in (j[k] as List? ?? const [])) f(Map<String, dynamic>.from(e as Map))];
    return Moment(
      id: j['id'] as String,
      userId: j['userId'] as String,
      title: (j['title'] as String?) ?? '',
      type: CreationType.parse(j['creationType'] as String?),
      mood: j['mood'] as String?,
      atmosphere: j['atmosphere'] as String?,
      timeOfDay: j['timeOfDay'] as String?,
      locationName: j['locationName'] as String?,
      latitude: _d(j['latitude']),
      longitude: _d(j['longitude']),
      musicTitle: j['musicTitle'] as String?,
      musicArtist: j['musicArtist'] as String?,
      musicAlbum: j['musicAlbum'] as String?,
      musicArtworkUrl: j['musicArtworkUrl'] as String?,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
      finishedAt: j['finishedAt'] == null ? null : _dt(j['finishedAt']),
      creations: list('creations', Creation.fromJson),
      inspirations: list('inspirations', Inspiration.fromJson),
      prompts: list('prompts', PromptAnswer.fromJson),
      media: list('media', MediaItem.fromJson),
    );
  }

  String get text => creations.where((c) => c.type == 'text').map((c) => c.textContent ?? '').join('\n');
  DrawingData? get drawing => creations.where((c) => c.type == 'drawing' && c.drawing != null).map((c) => c.drawing).firstOrNull;
  List<MediaItem> get images => media.where((m) => m.type == 'image').toList();
  bool get hasMusic => (musicTitle ?? '').isNotEmpty;
  bool get hasLocation => (locationName ?? '').isNotEmpty;
  /// Whether this only exists from autosave and was never explicitly saved.
  bool get isDraft => finishedAt == null;

  String displayTitle(AppLocalizations l10n) => title.trim().isEmpty ? _fallbackTitle(l10n) : title.trim();
  String _fallbackTitle(AppLocalizations l10n) {
    final t = text.trim();
    if (t.isNotEmpty) {
      final line = t.split('\n').first;
      return line.length > 40 ? '${line.substring(0, 40)}…' : line;
    }
    return switch (timeOfDay) {
      'night' => l10n.momentFallbackNight,
      'dawn' => l10n.momentFallbackDawn,
      'sunset' => l10n.momentFallbackSunset,
      _ => l10n.momentFallbackUntitled,
    };
  }

  /// First text snippet for cards.
  String get excerpt {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 140 ? '${t.substring(0, 140)}…' : t;
  }

  Set<String> get inspirationTypes => inspirations.map((e) => e.type).toSet();
}
