import 'dart:convert';
import 'dart:typed_data';

import 'package:creative_moments/core/errors/app_error.dart';
import 'package:creative_moments/data/models/drawing.dart';
import 'package:creative_moments/data/models/moment.dart';
import 'package:creative_moments/data/models/preferences.dart';
import 'package:creative_moments/data/repositories/moment_repository.dart';
import 'package:creative_moments/data/repositories/preferences_repository.dart';
import 'package:creative_moments/data/repositories/storage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercises the real repositories against a fake HTTP transport, so we check
/// exactly what would be sent to Supabase.
class Recorder {
  final requests = <http.Request>[];
  final Map<String, ({int status, Object body})> routes = {};

  MockClient get client => MockClient((req) async {
    requests.add(req);
    final key = '${req.method} ${req.url.path}';
    final r = routes[key];
    const headers = {'content-type': 'application/json'};
    if (r == null) {
      final isUpload = req.method == 'POST' && req.url.path.startsWith('/storage/v1/object/');
      return http.Response(isUpload ? '{"Key":"ok"}' : '[]', 200, request: req, headers: headers);
    }
    return http.Response(jsonEncode(r.body), r.status, request: req, headers: headers);
  });

  http.Request last(String method, String path) => requests.lastWhere((r) => r.method == method && r.url.path == path);
}

SupabaseClient clientFor(Recorder r) => SupabaseClient('https://demo.supabase.co', 'anon-key', httpClient: r.client);

const _row = {
  'id': 'm1',
  'user_id': 'u1',
  'title': 'Tonight',
  'creation_type': 'drawing',
  'created_at': '2026-09-25T21:40:00Z',
  'updated_at': '2026-09-25T21:40:00Z',
  'creations': [],
  'inspirations': [
    {'type': 'moon', 'name': 'Moon'},
  ],
  'prompts': [],
  'media': [],
};

void main() {
  late Recorder rec;
  late SupabaseClient client;
  late StorageRepository storage;
  late MomentRepository repo;

  setUp(() {
    rec = Recorder();
    client = clientFor(rec);
    storage = StorageRepository(client);
    repo = MomentRepository(client, storage);
  });

  test('list() reads moments newest-first with nested data in one query', () async {
    rec.routes['GET /rest/v1/moments'] = (status: 200, body: [_row]);
    final list = await repo.list();
    expect(list.single.id, 'm1');
    expect(list.single.inspirations.single.type, 'moon');
    final q = rec.last('GET', '/rest/v1/moments').url.queryParameters;
    expect(q['order'], startsWith('created_at.desc'));
    expect(q['select'], contains('creations(*)'));
    expect(q['select'], contains('prompts(*,answers(*))'));
  });

  test('saveCore() upserts the moment then its creations, with client ids', () async {
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
    final m = rec.last('POST', '/rest/v1/moments');
    expect(m.headers['Prefer'], contains('resolution=merge-duplicates'));
    final body = jsonDecode(m.body) as Map<String, dynamic>;
    expect(body['id'], 'm1');
    expect(body['user_id'], 'u1');
    expect(body['creation_type'], 'drawing');
    expect(body['mood'], 'peaceful');
    expect(body['created_at'], '2026-09-25T21:40:00.000Z');
    final c = jsonDecode(rec.last('POST', '/rest/v1/creations').body) as List;
    expect(c.length, 2);
    expect(c.map((e) => e['type']), containsAll(['text', 'drawing']));
    expect(c.first['moment_id'], 'm1');
  });

  test('saveDetails() calls the atomic RPC with inspirations and prompts', () async {
    await repo.saveDetails('m1', const [Inspiration(type: 'moon', name: 'Moon')], const [PromptAnswer(id: 'p1', question: 'Q?', answer: 'A')]);
    final body = jsonDecode(rec.last('POST', '/rest/v1/rpc/save_moment_details').body) as Map<String, dynamic>;
    expect(body['p_moment_id'], 'm1');
    expect(body['p_inspirations'], [
      {'type': 'moon', 'name': 'Moon'},
    ]);
    expect(body['p_prompts'].single, {'id': 'p1', 'question': 'Q?', 'answer': 'A'});
  });

  test('delete() removes the row and its stored files', () async {
    final m = Moment.fromJson({
      ..._row,
      'media': [
        {'id': 'x', 'moment_id': 'm1', 'type': 'image', 'storage_path': 'u1/m1/a.jpg'},
      ],
    });
    await repo.delete(m);
    expect(rec.last('DELETE', '/rest/v1/moments').url.queryParameters['id'], 'eq.m1');
    final rm = rec.requests.lastWhere((r) => r.url.path == '/storage/v1/object/moment-media');
    expect(jsonDecode(rm.body)['prefixes'], ['u1/m1/a.jpg']);
  });

  test('addMedia() stores files under <user>/<moment>/ so storage policies can scope them', () async {
    rec.routes['POST /rest/v1/media'] = (status: 201, body: {'id': 'x', 'moment_id': 'm1', 'type': 'image', 'storage_path': 'u1/m1/a.jpg'});
    final item = await repo.addMedia(userId: 'u1', momentId: 'm1', type: 'image', bytes: Uint8List(3), ext: 'jpg', contentType: 'image/jpeg');
    expect(item.id, 'x');
    final up = rec.requests.firstWhere((r) => r.url.path.startsWith('/storage/v1/object/moment-media/u1/m1/'));
    expect(up.url.path, matches(r'^/storage/v1/object/moment-media/u1/m1/\d+\.jpg$'));
    final row = jsonDecode(rec.last('POST', '/rest/v1/media').body) as Map<String, dynamic>;
    expect(row['storage_path'], startsWith('u1/m1/'));
  });

  test('database refusals become friendly messages', () async {
    rec.routes['GET /rest/v1/moments'] = (status: 403, body: {'code': '42501', 'message': 'new row violates row-level security policy for table "moments"'});
    try {
      await repo.list();
      fail('should throw');
    } catch (e) {
      final msg = friendlyError(e);
      expect(msg, isNot(contains('row-level')));
      expect(msg, isNotEmpty);
    }
  });

  test('preferences upsert sends the user id and every setting', () async {
    final prefs = PreferencesRepository(client);
    await prefs.save('u1', const UserPreferences(atmosphere: 'calm', reduceMotion: true, onboarded: true));
    final body = jsonDecode(rec.last('POST', '/rest/v1/user_preferences').body) as Map<String, dynamic>;
    expect(body['user_id'], 'u1');
    expect(body['atmosphere'], 'calm');
    expect(body['reduce_motion'], true);
    expect(body['onboarded'], true);
  });

  test('preferences fetch parses the row', () async {
    rec.routes['GET /rest/v1/user_preferences'] = (
      status: 200,
      body: {
        'user_id': 'u1',
        'environment': 'ocean',
        'environments': ['ocean'],
        'onboarded': true,
      },
    );
    final prefs = await PreferencesRepository(client).fetch('u1');
    expect(prefs.environment, 'ocean');
    expect(prefs.onboarded, isTrue);
  });
}
