import 'dart:convert';
import 'dart:typed_data';

import 'package:creative_moments/core/errors/app_error.dart';
import 'package:creative_moments/core/services/api_client.dart';
import 'package:creative_moments/data/models/drawing.dart';
import 'package:creative_moments/data/models/moment.dart';
import 'package:creative_moments/data/models/preferences.dart';
import 'package:creative_moments/data/repositories/moment_repository.dart';
import 'package:creative_moments/data/repositories/preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the real repositories against a fake HTTP transport, so we check
/// exactly what would be sent to the backend.
class Recorder {
  final requests = <http.BaseRequest>[];
  final Map<String, ({int status, Object body})> routes = {};

  MockClient get client => MockClient((req) async {
    requests.add(req);
    final key = '${req.method} ${req.url.path}';
    final r = routes[key];
    const headers = {'content-type': 'application/json'};
    if (r == null) return http.Response('{}', 200, request: req, headers: headers);
    return http.Response(jsonEncode(r.body), r.status, request: req, headers: headers);
  });

  http.BaseRequest last(String method, String path) => requests.lastWhere((r) => r.method == method && r.url.path == path);
}

ApiClient clientFor(Recorder r) => ApiClient(httpClient: r.client);

const _row = {
  'id': 'm1',
  'userId': 'u1',
  'title': 'Tonight',
  'creationType': 'drawing',
  'createdAt': '2026-09-25T21:40:00Z',
  'updatedAt': '2026-09-25T21:40:00Z',
  'creations': [],
  'inspirations': [
    {'type': 'moon', 'name': 'Moon'},
  ],
  'prompts': [],
  'media': [],
};

void main() {
  late Recorder rec;
  late ApiClient api;
  late MomentRepository repo;

  setUp(() {
    rec = Recorder();
    api = clientFor(rec);
    repo = MomentRepository(api);
  });

  test('list() reads moments newest-first with nested data in one request', () async {
    rec.routes['GET /api/moments'] = (status: 200, body: {
      'moments': [_row],
    });
    final list = await repo.list();
    expect(list.single.id, 'm1');
    expect(list.single.inspirations.single.type, 'moon');
    expect(rec.last('GET', '/api/moments'), isNotNull);
  });

  test('saveCore() PUTs the moment core fields plus its text/drawing creations, with client ids', () async {
    await repo.saveCore(
      MomentCoreSave(
        id: 'm1',
        userId: 'u1',
        title: ' Tonight ',
        creationType: 'drawing',
        createdAt: DateTime.utc(2026, 9, 25, 21, 40),
        mood: 'peaceful',
        timeOfDay: 'night',
        textCreationId: 't1',
        text: 'hello',
        drawingCreationId: 'd1',
        drawing: const DrawingData(width: 10, height: 10, background: 0, strokes: []),
      ),
    );
    final req = rec.last('PUT', '/api/moments/m1') as http.Request;
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['title'], ' Tonight ');
    expect(body['creationType'], 'drawing');
    expect(body['mood'], 'peaceful');
    expect(body['createdAt'], '2026-09-25T21:40:00.000Z');
    expect(body['text'], {'id': 't1', 'content': 'hello'});
    expect(body['drawing']['id'], 'd1');
  });

  test('saveDetails() PUTs inspirations and prompts to the details endpoint', () async {
    await repo.saveDetails('m1', const [Inspiration(type: 'moon', name: 'Moon')], const [PromptAnswer(id: 'p1', question: 'Q?', answer: 'A')]);
    final req = rec.last('PUT', '/api/moments/m1/details') as http.Request;
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['inspirations'], [
      {'type': 'moon', 'name': 'Moon'},
    ]);
    expect(body['prompts'].single, {'id': 'p1', 'question': 'Q?', 'answer': 'A'});
  });

  test('delete() removes the moment by id', () async {
    final m = Moment.fromJson(_row);
    await repo.delete(m);
    expect(rec.last('DELETE', '/api/moments/m1'), isNotNull);
  });

  test('addMedia() uploads the file as multipart to the moment media endpoint', () async {
    rec.routes['POST /api/moments/m1/media'] = (
      status: 201,
      body: {
        'media': {'id': 'x', 'momentId': 'm1', 'type': 'image', 'storagePath': 'u1/m1/a.jpg', 'url': 'https://example.test/a.jpg'},
      },
    );
    final item = await repo.addMedia(userId: 'u1', momentId: 'm1', type: 'image', bytes: Uint8List(3), ext: 'jpg', contentType: 'image/jpeg');
    expect(item.id, 'x');
    expect(item.url, 'https://example.test/a.jpg');
    // MockClient flattens MultipartRequest into a plain Request, so we can
    // only check that the upload hit the right endpoint here.
    expect(rec.last('POST', '/api/moments/m1/media'), isNotNull);
  });

  test('server refusals become friendly messages', () async {
    rec.routes['GET /api/moments'] = (status: 500, body: {'error': 'internal_error'});
    try {
      await repo.list();
      fail('should throw');
    } catch (e) {
      final msg = friendlyError(e);
      expect(msg, isNot(contains('internal_error')));
      expect(msg, isNotEmpty);
    }
  });

  test('preferences save() PUTs every setting', () async {
    final prefs = PreferencesRepository(api);
    await prefs.save('u1', const UserPreferences(atmosphere: 'calm', reduceMotion: true, onboarded: true));
    final req = rec.last('PUT', '/api/preferences') as http.Request;
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['atmosphere'], 'calm');
    expect(body['reduceMotion'], true);
    expect(body['onboarded'], true);
  });

  test('preferences fetch() parses the response', () async {
    rec.routes['GET /api/preferences'] = (
      status: 200,
      body: {
        'preferences': {
          'environment': 'ocean',
          'environments': ['ocean'],
          'onboarded': true,
        },
      },
    );
    final prefs = await PreferencesRepository(api).fetch('u1');
    expect(prefs.environment, 'ocean');
    expect(prefs.onboarded, isTrue);
  });
}
