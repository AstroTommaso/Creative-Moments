import 'dart:math';
import 'dart:typed_data';

import 'package:creative_moments/core/constants/catalog.dart';
import 'package:creative_moments/core/utils/question_selector.dart';
import 'package:creative_moments/data/models/drawing.dart';
import 'package:creative_moments/data/providers.dart';
import 'package:creative_moments/dev/fake_backend.dart';
import 'package:creative_moments/features/creation/draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

ProviderContainer containerFor(FakeBackend b) {
  final c = ProviderContainer(retry: (_, _) => null, overrides: b.overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late FakeBackend backend;
  late ProviderContainer c;
  DraftNotifier draft() => c.read(draftProvider.notifier);
  DraftState state() => c.read(draftProvider);

  setUp(() {
    backend = signedInBackend();
    c = containerFor(backend);
    c.listen(sessionUserProvider, (_, _) {}); // keep alive
  });

  test('an untouched draft saves nothing', () async {
    draft().start(CreationType.writing);
    await draft().save();
    expect(backend.moments, isEmpty);
    expect(state().status, SaveStatus.idle);
  });

  test('typing marks the draft as not saved, save() persists to the backend and confirms', () async {
    draft().start(CreationType.writing);
    draft().setTitle('Night walk');
    draft().setBody('Streetlights.');
    expect(state().status, SaveStatus.dirty);
    expect(state().unsaved, isTrue);
    await draft().save();
    expect(state().status, SaveStatus.saved);
    expect(state().unsaved, isFalse);
    final m = backend.moments.values.single;
    expect(m.title, 'Night walk');
    expect(m.text, 'Streetlights.');
    expect(m.type, CreationType.writing);
    expect(m.timeOfDay, isNotNull);
  });

  test('saving twice updates the same moment instead of creating duplicates', () async {
    draft().start(CreationType.writing);
    draft().setBody('one');
    await draft().save();
    draft().setBody('one two');
    await draft().save();
    expect(backend.moments.length, 1);
    expect(backend.moments.values.single.text, 'one two');
  });

  test('when the network drops the draft stays in memory and is never reported as saved', () async {
    draft().start(CreationType.writing);
    draft().setBody('precious words');
    backend.offline = true;
    await draft().save();
    expect(state().status, SaveStatus.error);
    expect(state().unsaved, isTrue);
    expect(state().body, 'precious words');
    expect(state().error, isNot(contains('Exception')));
    expect(backend.moments, isEmpty);

    backend.offline = false; // connection returns → next attempt syncs
    await draft().save();
    expect(state().status, SaveStatus.saved);
    expect(backend.moments.values.single.text, 'precious words');
  });

  test('edits made while a save is in flight are not lost or marked saved', () async {
    draft().start(CreationType.writing);
    draft().setBody('a');
    final first = draft().save();
    draft().setBody('ab');
    await first;
    await Future<void>.delayed(Duration.zero);
    await draft().save();
    expect(backend.moments.values.single.text, 'ab');
    expect(state().status, SaveStatus.saved);
  });

  test('drawings are stored as vector JSON alongside the moment', () async {
    draft().start(CreationType.drawing);
    draft().setDrawing(
      DrawingData(
        width: 300,
        height: 400,
        background: 0xFF000000,
        strokes: [
          Stroke(tool: BrushTool.pencil, color: 0xFFFFFFFF, width: 3, points: const [Offset(1, 1), Offset(9, 9)]),
        ],
      ),
    );
    await draft().save();
    final m = backend.moments.values.single;
    expect(m.drawing, isNotNull);
    expect(m.drawing!.strokes.single.points.length, 2);
  });

  test('images are uploaded on save and recorded as media', () async {
    draft().start(CreationType.photo);
    draft().addImage(PendingImage(id: 'i1', bytes: Uint8List.fromList([1, 2, 3]), ext: 'jpg', contentType: 'image/jpeg'));
    await draft().save();
    final m = backend.moments.values.single;
    expect(m.images.length, 1);
    expect(backend.files.keys.single, startsWith('${m.userId}/${m.id}/'));
    expect(state().pendingImages, isEmpty);
    expect(state().images.length, 1);
  });

  test('inspirations toggle on and off; custom "something else" keeps the text', () {
    draft().start(CreationType.idea);
    draft().toggleInspiration('moon');
    draft().toggleInspiration('city');
    draft().toggleInspiration('moon');
    expect(state().inspirations.map((e) => e.type), ['city']);
    draft().toggleInspiration('other', name: 'Something else');
    draft().setCustomInspiration('a train at dawn');
    expect(state().inspirations.last.name, 'a train at dawn');
  });

  test('questions depend on the moment, do not repeat, and never have to be answered', () async {
    draft().useSelector(QuestionSelector(random: Random(4)));
    draft().start(CreationType.writing);
    draft().toggleInspiration('rain');
    draft().setBody('x');
    final ids = <String>{};
    for (var i = 0; i < 10; i++) {
      expect(draft().nextQuestion(), isTrue);
      expect(ids.add(state().question!.id), isTrue);
    }
    // skip: finish without an answer stores no prompt
    await draft().finish();
    expect(backend.moments.values.single.prompts, isEmpty);
  });

  test('finish() stores inspirations, mood, music, place and an answered question', () async {
    draft().start(CreationType.writing);
    draft().setTitle('Rain');
    draft().setBody('Drops.');
    draft().toggleInspiration('rain');
    draft().toggleInspiration('music');
    draft().setMood('peaceful');
    draft().setMusic(const Music(title: 'Nuvole Bianche', artist: 'Einaudi'));
    draft().setPlace(const Place(name: 'Milano', latitude: 45.4, longitude: 9.19));
    draft().nextQuestion();
    draft().setAnswer('Loneliness, but peaceful.');
    final id = await draft().finish();

    final m = backend.moments[id]!;
    expect(m.inspirations.map((e) => e.type).toSet(), {'rain', 'music'});
    expect(m.mood, 'peaceful');
    expect(m.musicTitle, 'Nuvole Bianche');
    expect(m.musicArtist, 'Einaudi');
    expect(m.locationName, 'Milano');
    expect(m.latitude, 45.4);
    expect(m.prompts.single.answer, 'Loneliness, but peaceful.');
    expect(c.read(lastCreatedProvider), id);
    expect(c.read(momentsProvider).value!.map((e) => e.id), contains(id));
  });

  test('finish() fails loudly (friendly) when offline instead of pretending to save', () async {
    draft().start(CreationType.writing);
    draft().setBody('x');
    backend.offline = true;
    await expectLater(draft().finish(), throwsA(predicate((e) => !e.toString().contains('SocketException'))));
    expect(backend.moments, isEmpty);
  });

  test('editing an existing moment keeps its identity and does not re-trigger the new-star effect', () async {
    draft().start(CreationType.writing);
    draft().setBody('first');
    final id = await draft().finish();
    c.read(lastCreatedProvider.notifier).set(null);

    final m = backend.moments[id]!;
    draft().loadExisting(m);
    expect(state().isEditing, isTrue);
    expect(state().body, 'first');
    draft().setBody('second');
    final again = await draft().finish();
    expect(again, id);
    expect(backend.moments.length, 1);
    expect(backend.moments[id]!.text, 'second');
    expect(c.read(lastCreatedProvider), isNull);
  });

  test('discard removes a brand-new moment that autosave already stored', () async {
    draft().start(CreationType.writing);
    draft().setBody('regret');
    await draft().save();
    expect(backend.moments.length, 1);
    await draft().discard();
    expect(backend.moments, isEmpty);
  });

  test('deleting a moment removes it from the list and backend', () async {
    draft().start(CreationType.writing);
    draft().setBody('bye');
    final id = await draft().finish();
    await c.read(momentsProvider.notifier).delete(backend.moments[id]!);
    expect(backend.moments, isEmpty);
    expect(c.read(momentsProvider).value, isEmpty);
  });
}
