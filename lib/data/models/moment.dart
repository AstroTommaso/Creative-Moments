import '../../core/constants/catalog.dart';
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
    momentId: j['moment_id'] as String,
    type: j['type'] as String,
    textContent: j['text_content'] as String?,
    drawing: j['drawing_data'] == null ? null : DrawingData.fromJson(Map<String, dynamic>.from(j['drawing_data'] as Map)),
    createdAt: _dt(j['created_at']),
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

  factory PromptAnswer.fromJson(Map<String, dynamic> j) {
    final answers = (j['answers'] as List? ?? const []);
    return PromptAnswer(id: j['id'] as String, question: j['question'] as String, answer: answers.isEmpty ? null : (answers.first as Map)['answer'] as String?);
  }
  Map<String, dynamic> toJson() => {'id': id, 'question': question, 'answer': answer};
}

class MediaItem {
  const MediaItem({required this.id, required this.momentId, required this.type, required this.storagePath});
  final String id, momentId, type, storagePath;
  factory MediaItem.fromJson(Map<String, dynamic> j) =>
      MediaItem(id: j['id'] as String, momentId: j['moment_id'] as String, type: j['type'] as String, storagePath: j['storage_path'] as String);
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
  final List<Creation> creations;
  final List<Inspiration> inspirations;
  final List<PromptAnswer> prompts;
  final List<MediaItem> media;

  static const select = '*, creations(*), inspirations(*), prompts(*, answers(*)), media(*)';

  factory Moment.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [for (final e in (j[k] as List? ?? const [])) f(Map<String, dynamic>.from(e as Map))];
    final prompts = list('prompts', PromptAnswer.fromJson);
    return Moment(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: (j['title'] as String?) ?? '',
      type: CreationType.parse(j['creation_type'] as String?),
      mood: j['mood'] as String?,
      atmosphere: j['atmosphere'] as String?,
      timeOfDay: j['time_of_day'] as String?,
      locationName: j['location_name'] as String?,
      latitude: _d(j['latitude']),
      longitude: _d(j['longitude']),
      musicTitle: j['music_title'] as String?,
      musicArtist: j['music_artist'] as String?,
      musicAlbum: j['music_album'] as String?,
      musicArtworkUrl: j['music_artwork_url'] as String?,
      createdAt: _dt(j['created_at']),
      updatedAt: _dt(j['updated_at']),
      creations: list('creations', Creation.fromJson),
      inspirations: list('inspirations', Inspiration.fromJson),
      prompts: prompts,
      media: list('media', MediaItem.fromJson),
    );
  }

  String get text => creations.where((c) => c.type == 'text').map((c) => c.textContent ?? '').join('\n');
  DrawingData? get drawing => creations.where((c) => c.type == 'drawing' && c.drawing != null).map((c) => c.drawing).firstOrNull;
  List<MediaItem> get images => media.where((m) => m.type == 'image').toList();
  bool get hasMusic => (musicTitle ?? '').isNotEmpty;
  bool get hasLocation => (locationName ?? '').isNotEmpty;
  String get displayTitle => title.trim().isEmpty ? _fallbackTitle : title.trim();
  String get _fallbackTitle {
    final t = text.trim();
    if (t.isNotEmpty) {
      final line = t.split('\n').first;
      return line.length > 40 ? '${line.substring(0, 40)}…' : line;
    }
    return switch (timeOfDay) {
      'night' => 'A night moment',
      'dawn' => 'An early moment',
      'sunset' => 'A sunset moment',
      _ => 'Untitled moment',
    };
  }

  /// First text snippet for cards.
  String get excerpt {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 140 ? '${t.substring(0, 140)}…' : t;
  }

  Set<String> get inspirationTypes => inspirations.map((e) => e.type).toSet();
}
