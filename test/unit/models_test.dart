import 'package:creative_moments/core/constants/catalog.dart';
import 'package:creative_moments/data/models/drawing.dart';
import 'package:creative_moments/data/models/moment.dart';
import 'package:creative_moments/data/models/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> momentJson({Map<String, dynamic>? extra}) => {
  'id': 'm1',
  'userId': 'u1',
  'title': 'Tonight',
  'creationType': 'writing',
  'mood': 'peaceful',
  'atmosphere': 'dreamy',
  'timeOfDay': 'night',
  'locationName': 'Italy',
  'latitude': 45.4,
  'longitude': 9.19,
  'musicTitle': 'Nuvole Bianche',
  'musicArtist': 'Einaudi',
  'createdAt': '2026-09-25T21:40:00Z',
  'updatedAt': '2026-09-25T21:41:00Z',
  'creations': [
    {'id': 'c1', 'momentId': 'm1', 'type': 'text', 'textContent': 'Hello\nworld', 'drawingData': null, 'createdAt': '2026-09-25T21:40:00Z'},
  ],
  'inspirations': [
    {'type': 'moon', 'name': 'Moon'},
    {'type': 'city', 'name': 'City'},
  ],
  'prompts': [
    {'id': 'p1', 'question': 'Q?', 'answer': 'A.'},
    {'id': 'p2', 'question': 'Skipped?', 'answer': null},
  ],
  'media': [
    {'id': 'x1', 'momentId': 'm1', 'type': 'image', 'storagePath': 'u1/m1/a.jpg', 'url': 'https://example.test/a.jpg'},
  ],
  ...?extra,
};

void main() {
  group('Moment.fromJson', () {
    test('parses nested creations, inspirations, prompts and media', () {
      final m = Moment.fromJson(momentJson());
      expect(m.type, CreationType.writing);
      expect(m.text, 'Hello\nworld');
      expect(m.inspirations.map((e) => e.type), ['moon', 'city']);
      expect(m.prompts.first.answer, 'A.');
      expect(m.prompts.last.answer, isNull);
      expect(m.images.single.storagePath, 'u1/m1/a.jpg');
      expect(m.images.single.url, 'https://example.test/a.jpg');
      expect(m.hasMusic, isTrue);
      expect(m.hasLocation, isTrue);
      expect(m.latitude, 45.4);
      expect(m.inspirationTypes, {'moon', 'city'});
    });

    test('tolerates missing optional parts and unknown type', () {
      final m = Moment.fromJson({
        'id': 'm',
        'userId': 'u',
        'creationType': 'mystery',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      });
      expect(m.type, CreationType.freeform);
      expect(m.creations, isEmpty);
      expect(m.text, '');
      expect(m.hasMusic, isFalse);
    });

    test('displayTitle falls back to first line of text, then to time of day', () {
      expect(Moment.fromJson(momentJson()).displayTitle, 'Tonight');
      expect(Moment.fromJson(momentJson(extra: {'title': ''})).displayTitle, 'Hello');
      expect(Moment.fromJson(momentJson(extra: {'title': '', 'creations': []})).displayTitle, 'A night moment');
      final long = Moment.fromJson(
        momentJson(
          extra: {
            'title': '',
            'creations': [
              {'id': 'c', 'momentId': 'm1', 'type': 'text', 'textContent': 'x' * 100, 'createdAt': '2026-09-25T21:40:00Z'},
            ],
          },
        ),
      );
      expect(long.displayTitle.length, lessThanOrEqualTo(41));
    });

    test('excerpt collapses whitespace and truncates', () {
      final m = Moment.fromJson(
        momentJson(
          extra: {
            'creations': [
              {'id': 'c', 'momentId': 'm1', 'type': 'text', 'textContent': 'a\n\n  b ${'z' * 200}', 'createdAt': '2026-09-25T21:40:00Z'},
            ],
          },
        ),
      );
      expect(m.excerpt.startsWith('a b z'), isTrue);
      expect(m.excerpt.endsWith('…'), isTrue);
    });
  });

  group('DrawingData', () {
    test('round-trips through JSON with reduced precision', () {
      final d = DrawingData(
        width: 300,
        height: 400,
        background: 0xFF12142A,
        strokes: [
          Stroke(tool: BrushTool.brush, color: 0xFFE9C98F, width: 4.44, points: const [Offset(1.23, 2.34), Offset(10, 20.05)]),
          Stroke(tool: BrushTool.eraser, color: 0xFF000000, width: 9, points: const [Offset(5, 5)]),
        ],
      );
      final back = DrawingData.fromJson(d.toJson());
      expect(back.width, 300);
      expect(back.strokes.length, 2);
      expect(back.strokes.first.tool, BrushTool.brush);
      expect(back.strokes.first.points.first, const Offset(1.2, 2.3));
      expect(back.strokes.last.tool, BrushTool.eraser);
      expect(back.isEmpty, isFalse);
    });

    test('an unknown tool decodes as pencil and empty drawing is empty', () {
      final s = Stroke.fromJson({
        't': 'laser',
        'c': 1,
        'w': 2,
        'p': [1, 2, 3, 4],
      });
      expect(s.tool, BrushTool.pencil);
      expect(s.points.length, 2);
      expect(const DrawingData(width: 1, height: 1, background: 0).isEmpty, isTrue);
    });
  });

  group('UserPreferences', () {
    test('round-trips and keeps defaults for missing fields', () {
      const p = UserPreferences(
        environments: ['ocean', 'moon'],
        environment: 'ocean',
        atmosphere: 'calm',
        timeStyle: 'night',
        visualDensity: 'immersive',
        reduceMotion: true,
        onboarded: true,
      );
      final json = p.toJson();
      expect(json['environment'], 'ocean');
      final back = UserPreferences.fromJson(json);
      expect(back.environments, ['ocean', 'moon']);
      expect(back.timeStyle, 'night');
      expect(back.reduceMotion, isTrue);
      final sparse = UserPreferences.fromJson({});
      expect(sparse.darkMode, isTrue);
      expect(sparse.onboarded, isFalse);
      expect(sparse.environment, 'moon');
    });

    test('activeEnvironments lists the primary first, without duplicates', () {
      const p = UserPreferences(environments: ['stars', 'moon', 'ocean'], environment: 'moon');
      expect(p.activeEnvironments, ['moon', 'stars', 'ocean']);
    });

    test('copyWith changes only what it is given', () {
      const p = UserPreferences();
      final q = p.copyWith(atmosphere: 'warm', reduceMotion: true);
      expect(q.atmosphere, 'warm');
      expect(q.reduceMotion, isTrue);
      expect(q.environment, p.environment);
    });
  });
}
